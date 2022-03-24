module server

import despiegk.crystallib.resp2
import json
import time
import net.http

const reply_forward_retries = 3

fn (mut ctx MBusSrv) handle_from_reply_forward(mut msg Message) {
	// reply have only one destination (source)
	dst := msg.twin_dst[0]
	mut error_msg := ''
	mut response := http.Response{}
	mut dest := ''
	ctx.logger.debug('MSG $msg.id - resolving twin: $dst')
	// handling network/server issues when sending the replay over http by retrying
	for i in 0 .. server.reply_forward_retries {
		error_msg = ''
		dest = ctx.resolver(u32(dst)) or {
			error_msg = "couldn't resolve twin ip with error: $err"
			ctx.logger.debug('MSG $msg.id - attempt $i - $error_msg')
			continue
		}

		ctx.logger.debug('forwarding reply to $dest\n$msg')
		msg.epoch = time.now().unix_time()

		// forward to reply agent
		response = http.post('http://$dest:8051/zbus-reply', json.encode(msg)) or {
			error_msg = 'failed to send post request to $dest with error: $err'
			ctx.logger.debug('MSG $msg.id - attempt $i - $error_msg')
			continue
		}

		if response.status() != http.Status.ok {
			error_msg = 'got error response from twin $dst:\nstatus code: $response.status_code\nresponse: $response.text'
			ctx.logger.debug('MSG $msg.id - attempt $i - $error_msg')
			continue
		}
		break
	}
	if error_msg != '' {
		ctx.logger.error("MSG $msg.id - couldn't send reply and all retries done. last error was: $error_msg")
	} else {
		ctx.logger.debug('MSG $msg.id - $response')
		ctx.logger.info('MSG $msg.id - Reply sent to $dest')
	}
}

fn (mut ctx MBusSrv) handle_from_reply_for_me(mut msg Message) {
	ctx.logger.debug('MSG $msg.id - message reply for me, fetching backlog\n$msg')

	retval := ctx.redis.hget('msgbus.system.backlog', msg.id) or {
		ctx.logger.error('MSG $msg.id - error fetching original message from backlog with error: $err')
		return
	}

	original := json.decode(Message, retval) or {
		ctx.logger.critical('MSG $msg.id - original message decode failed with error: $err')
		return
	}

	// restore return queue name for the caller
	msg.retqueue = original.retqueue
	ctx.logger.debug('MSG $msg.id - original retqueue: $original.retqueue')

	// forward reply to original sender
	ctx.redis.lpush(msg.retqueue, json.encode(msg)) or {
		ctx.logger.critical('MSG $msg.id - failed to push message to redis return queue $msg.retqueue with error: $err')
		return
	}

	// Make key expire after 30 mins
	expire_time_in_sec := 30 * 60
	ctx.redis.expire(msg.retqueue, expire_time_in_sec) or {
		ctx.logger.critical('MSG $msg.id - failed to set expire time to redis return queue $msg.retqueue with error: $err')
		return
	}

	// remove from backlog
	ctx.redis.hdel('msgbus.system.backlog', msg.id) or {
		ctx.logger.critical('MSG $msg.id - failed to delete message from backlog with error: $err')
		return
	}
	ctx.logger.info('MSG $msg.id - Pushed to $msg.retqueue')
}

fn (mut ctx MBusSrv) handle_from_reply_for_proxy(mut msg Message) {
	ctx.logger.debug('MSG $msg.id - message reply for proxy\n$msg')

	// forward reply to original sender
	ctx.redis.lpush(msg.retqueue, json.encode(msg)) or {
		ctx.logger.critical('MSG $msg.id - failed to push message to redis with error: $err')
		return
	}

	// Make key expire after 30 mins
	expire_time_in_sec := 30 * 60
	ctx.redis.expire(msg.retqueue, expire_time_in_sec) or {
		ctx.logger.critical('MSG $msg.id - failed to set expire time to $msg.retqueue with error: $err')
		return
	}
	ctx.logger.info('MSG $msg.id - Pushed to $msg.retqueue')
}

fn (mut ctx MBusSrv) handle_from_reply(mut msg Message) {
	if msg.proxy {
		ctx.handle_from_reply_for_proxy(mut msg)
	} else if msg.twin_dst[0] == ctx.myid {
		ctx.handle_from_reply_for_me(mut msg)
	} else if msg.twin_src == ctx.myid {
		ctx.handle_from_reply_forward(mut msg)
	}
}

fn (mut ctx MBusSrv) handle_from_remote(mut msg Message) {
	ctx.logger.debug('MSG $msg.id - forwarding to local service: msgbus.' + msg.command)

	// forward to local service
	ctx.redis.lpush('msgbus.' + msg.command, json.encode(msg)) or {
		ctx.logger.critical('failed to push ($msg.command) with error: $err')
		return
	}
}

fn (mut ctx MBusSrv) msg_needs_retry(mut msg Message, retry_reason string) {
	ctx.logger.debug('MSG $msg.id - needs retry due to $retry_reason')

	msg.epoch = time.now().unix_time()
	if msg.retry <= 0 {
		msg.err = 'could not send request and all retries done, last error: $retry_reason'
		output := json.encode(msg)
		ctx.redis.lpush(msg.retqueue, output) or {
			ctx.logger.critical('failed to respond to the caller with the proper error, due to $err')
			return
		}
		ctx.logger.error('MSG $msg.id - no more retry, replying with error $msg.err')
		return
	}

	ctx.logger.debug('MSG $msg.id - retry set to $msg.retry, adding to retry list')

	// remove one retry
	msg.retry -= 1

	value := json.encode(msg)
	ctx.redis.hset('msgbus.system.retry', msg.id, value) or {
		ctx.logger.critical('failed to push message in reply queue with error: $err')
	}
}

fn (mut ctx MBusSrv) handle_from_local_item(mut msg Message, dst int) {
	msg.epoch = time.now().unix_time()
	mut update := msg
	update.twin_src = ctx.myid
	update.twin_dst = [dst]
	mut single_dst_message := msg
	single_dst_message.twin_dst = [dst]

	mut error_msg := ''
	defer {
		if error_msg != '' {
			ctx.msg_needs_retry(mut single_dst_message, error_msg)
		}
	}
	// if error happens here no need to proceed to msg_needs_retry without id being set in the message
	id := ctx.redis.incr('msgbus.counter.$dst') or {
		ctx.logger.critical('BUG: message will not be send. failed to increment msgbus.counter.$dst with error: $err')
		return
	}
	single_dst_message.id = '${dst}.$id'

	ctx.logger.debug('MSG $single_dst_message.id - resolving twin: $dst')
	mut dest := ctx.resolver(u32(dst)) or {
		error_msg = 'failed to resolve twin ($dst) destination'
		ctx.logger.debug('MSG $single_dst_message.id - $error_msg')
		return
	}

	update.id = '${dst}.$id'
	update.retqueue = 'msgbus.system.reply'
	update.epoch = time.now().unix_time()

	ctx.logger.debug('MSG $update.id - forwarding msg to $dest\n$update')
	output := json.encode(update)
	response := http.post('http://$dest:8051/zbus-remote', output) or {
		error_msg = 'failed to send message to twin $dst with error: $err'
		ctx.logger.debug('MSG $update.id - $error_msg')
		return
	}

	if response.status() != http.Status.ok {
		error_msg = 'got error response from twin $dst:\nstatus code: $response.status_code\nresponse: $response.text'
		ctx.logger.debug('MSG $update.id - $error_msg')
		return
	}

	ctx.logger.debug('MSG $update.id - $response')
	ctx.logger.info('MSG $update.id - sent to target msgbus $dest')

	// keep message sent into backlog
	// needed to find back return queue etc.
	ctx.redis.hset('msgbus.system.backlog', update.id, json.encode(msg)) or {
		ctx.logger.critical('MSG $update.id - message sent but failed to push message to backlog with error: $err')
		return
	}
}

fn (mut ctx MBusSrv) handle_from_local(mut msg Message) {
	for dst in msg.twin_dst {
		ctx.handle_from_local_item(mut msg, dst)
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
			ctx.logger.error('decode failed hgetall message')
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
	mut entries := ctx.hgetall_result('msgbus.system.backlog') or { return error('$err') }

	now := time.now().unix_time()

	// iterate over each entries
	for mut entry in entries {
		if entry.value.expiration == 0 {
			// avoid infinite expiration, fallback to 1h
			entry.value.expiration = 3600
		}

		if entry.value.epoch + entry.value.expiration < now {
			ctx.logger.debug('MSG $entry.key - Message expired')

			entry.value.err = 'request timeout (expiration reached, $entry.value.expiration seconds)'
			output := json.encode(entry.value)

			ctx.redis.lpush(entry.value.retqueue, output) or {
				ctx.logger.error('failed to push message with proper error due to $err')
			}
			ctx.redis.hdel('msgbus.system.backlog', entry.key) or {
				ctx.logger.error('failed to delete $entry.key from backlog')
			}
		}
	}
}

fn (mut ctx MBusSrv) handle_retry() ? {
	// ctx.logger.debug('[+] checking retries')

	mut entries := ctx.hgetall_result('msgbus.system.retry') or { return error('$err') }

	now := time.now().unix_time()

	// iterate over each entries
	for mut entry in entries {
		if now > entry.value.epoch + 5 {
			ctx.logger.debug('MSG $entry.key - message needs retry')

			// remove from retry list
			ctx.redis.hdel('msgbus.system.retry', entry.key) or {
				ctx.logger.error('MSG $entry.key - failed to delete from retry queue with error: $err')
			}

			// re-call sending function, which will succeed or put it back to retry
			ctx.handle_from_local_item(mut entry.value, entry.value.twin_dst[0])
		}
	}
}
