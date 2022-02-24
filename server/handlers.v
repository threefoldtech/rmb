module server

import despiegk.crystallib.resp2
import json
import time
import net.http

fn (mut ctx MBusSrv) handle_from_reply_forward(mut msg Message) ? {
	// reply have only one destination (source)
	dst := msg.twin_dst[0]

	println('[+] resolving twin: $dst')
	mut dest := ctx.resolver(u32(dst)) or {
		return error("couldn't resolve twin ip with error: $err")
	}

	println('[+] forwarding reply to $dest')

	msg.epoch = time.now().unix_time()
	// forward to reply agent
	response := http.post('http://$dest:8051/zbus-reply', json.encode(msg)) or {
		return error('failed to send post request to $dest with error: $err')
	}

	if response.status() != http.Status.ok {
		return error('failed to send remote: $response.status_code ($response.text)')
	}
	println(response)
}

fn (mut ctx MBusSrv) handle_from_reply_for_me(mut msg Message) ? {
	println('[+] message reply for me, fetching backlog')

	retval := ctx.redis.hget('msgbus.system.backlog', msg.id) or {
		return error('error fetching message from backend with error: $err')
	}

	original := json.decode(Message, retval) or {
		return error('original decode failed with error: $err')
	}
	// restore return queue name for the caller
	msg.retqueue = original.retqueue

	// forward reply to original sender
	ctx.redis.lpush(msg.retqueue, json.encode(msg)) or {
		return error('failed to push message to redis with error: $err')
	}

	// Make key expire after 30 mins
	expire_time_in_sec := 30 * 60
	ctx.redis.expire(msg.retqueue, expire_time_in_sec) or {
		return error('failed to set expire time to $msg.retqueue with error: $err')
	}

	// remove from backlog
	ctx.redis.hdel('msgbus.system.backlog', msg.id) ?
}

fn (mut ctx MBusSrv) handle_from_reply_for_proxy(mut msg Message) ? {
	println('[+] message reply for proxy')

	// forward reply to original sender
	ctx.redis.lpush(msg.retqueue, json.encode(msg)) or {
		return error('failed to push message to redis with error: $err')
	}

	// Make key expire after 30 mins
	expire_time_in_sec := 30 * 60
	ctx.redis.expire(msg.retqueue, expire_time_in_sec) or {
		return error('failed to set expire time to $msg.retqueue with error: $err')
	}
}

fn (mut ctx MBusSrv) handle_from_reply(mut msg Message) ? {
	// TODO: Validate msg once when receving it
	msg.validate() or { return error('reply: validation failed with error: $err') }

	if msg.proxy {
		ctx.handle_from_reply_for_proxy(mut msg) or {
			return error('failed to handle reply proxy with error: $err')
		}
	} else if msg.twin_dst[0] == ctx.myid {
		ctx.handle_from_reply_for_me(mut msg) or {
			return error('failed to handle reply for me with error: $err')
		}
	} else if msg.twin_src == ctx.myid {
		ctx.handle_from_reply_forward(mut msg) or {
			return error('failed to handle reply forward with error: $err')
		}
	}
}

fn (mut ctx MBusSrv) handle_from_remote(mut msg Message) ? {
	// TODO: Validate msg once when receving it
	msg.validate() or { return error('remote: validation failed with error: $err') }

	println('[+] forwarding to local service: msgbus.' + msg.command)

	// forward to local service
	ctx.redis.lpush('msgbus.' + msg.command, json.encode(msg)) or {
		return error('failed to push ($msg.command) with error: $err')
	}
}

fn (mut ctx MBusSrv) msg_needs_retry(mut msg Message) ? {
	println('[-] could not send message to remote msgbus')

	if msg.retry <= 0 {
		msg.err = 'could not send request and all retries done'
		output := json.encode(msg)
		ctx.redis.lpush(msg.retqueue, output) or {
			return error('failed to respond to the caller with the proper error, due to $err')
		}
		return error('no more retry, replying with error')
	}

	println('[-] retry set to $msg.retry, adding to retry list')

	// remove one retry
	msg.retry -= 1
	msg.epoch = time.now().unix_time()

	value := json.encode(msg)
	ctx.redis.hset('msgbus.system.retry', msg.id, value) or {
		return error('faield to push message in reply queue with error: $err')
	}
}

fn (mut ctx MBusSrv) handle_from_local_item(mut msg Message, dst int) ? {
	msg.epoch = time.now().unix_time()
	mut update := msg
	update.twin_src = ctx.myid
	update.twin_dst = [dst]

	ctx.debug('[+] resolving twin: $dst')

	mut error_msg := ''
	defer {
		if error_msg != '' {
			ctx.msg_needs_retry(mut msg) or {
				eprintln('failed while processing message retry with error: $err')
				eprintln('original error: $error_msg')
			}
		}
	}
	mut dest := ctx.resolver(u32(dst)) or {
		error_msg = 'failed to resolve twin ($dst) destination'
		return error(error_msg)
		/*
		* What is the need to push the msg if failed to resolve destination ?
		* output := json.encode(update)
		* ctx.redis.lpush(update.retqueue, output) ?
		* return
		*/
	}

	id := ctx.redis.incr('msgbus.counter.$dst') or {
		error_msg = 'failed to increment msgbus.counter.$dst with error: $err'
		return error(error_msg)
	}

	update.id = '${dst}.$id'
	update.retqueue = 'msgbus.system.reply'
	update.epoch = time.now().unix_time()

	ctx.debug('[+] forwarding to $dest')

	output := json.encode(update)
	response := http.post('http://$dest:8051/zbus-remote', output) or {
		error_msg = 'failed to send remote with error: $err'
		return error(error_msg)
	}

	if response.status() != http.Status.ok {
		error_msg = 'failed to send remote: $response.status_code ($response.text)'
		return error(error_msg)
	}

	ctx.debug('[+] message sent to target msgbus')
	ctx.debug(response.str())

	// keep message sent into backlog
	// needed to find back return queue etc.
	ctx.redis.hset('msgbus.system.backlog', update.id, json.encode(msg)) or {
		error_msg = 'failed to push message in backlog with error: $err'
		return error(error_msg)
	}
}

fn (mut ctx MBusSrv) handle_from_local(mut msg Message) ? {
	// TODO: Validate msg once when receving it
	msg.validate() or { return error('local: could not validate input with error: $err') }

	for dst in msg.twin_dst {
		ctx.handle_from_local_item(mut msg, dst) or {
			eprintln('failed to handle message in handle_from_local_item with error: $err')
		}
	}
}

fn (mut ctx MBusSrv) hgetall_result(key string) ?[]HSetEntry {
	lines := ctx.redis.hgetall(key) or {
		return error('failed to read $key result with error: $err')
	}
	mut entries := []HSetEntry{}

	// build usable list from redis response
	for i := 0; i < lines.len; i += 2 {
		value := resp2.get_redis_value(lines[i + 1])
		message := json.decode(Message, value) or {
			eprintln('decode failed hgetall message')
			continue
		}

		entries << HSetEntry{
			key: resp2.get_redis_value(lines[i])
			value: message
		}
	}

	return entries
}

fn (mut ctx MBusSrv) handle_scrubbing() ? {
	// ctx.debug('[+] scrubbing')

	mut entries := ctx.hgetall_result('msgbus.system.backlog') or { return error('$err') }

	now := time.now().unix_time()

	// iterate over each entries
	for mut entry in entries {
		if entry.value.expiration == 0 {
			// avoid infinite expiration, fallback to 1h
			entry.value.expiration = 3600
		}

		if entry.value.epoch + entry.value.expiration < now {
			ctx.debug('[+] expired: $entry.key')

			entry.value.err = 'request timeout (expiration reached, $entry.value.expiration seconds)'
			output := json.encode(entry.value)

			ctx.redis.lpush(entry.value.retqueue, output) or {
				eprintln('failed to push message with proper error due to $err')
			}
			ctx.redis.hdel('msgbus.system.backlog', entry.key) or {
				eprintln('failed to delete $entry.key from backlog')
			}
		}
	}
}

fn (mut ctx MBusSrv) handle_retry() ? {
	// ctx.debug('[+] checking retries')

	mut entries := ctx.hgetall_result('msgbus.system.retry') or { return error('$err') }

	now := time.now().unix_time()

	// iterate over each entries
	for mut entry in entries {
		if now > entry.value.epoch + 5 {
			println('[+] retry needed: $entry.key')

			// remove from retry list
			ctx.redis.hdel('msgbus.system.retry', entry.key) or {
				eprintln('error deleting $entry.key from retry queue with error: $err')
			}

			// re-call sending function, which will succeed or put it back to retry
			ctx.handle_from_local_item(mut entry.value, entry.value.twin_dst[0]) or {
				eprintln('error from handle_from_local_item for $entry.value.id, retry handled from there')
			}
		}
	}
}

fn (ctx MBusSrv) debug(msg string) {
	if ctx.debugval > 0 {
		println(msg)
	}
}
