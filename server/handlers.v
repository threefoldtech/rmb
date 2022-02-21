module server

import despiegk.crystallib.redisclient
import despiegk.crystallib.resp2
import json
import time
import net.http

fn (mut ctx MBusSrv) handle_from_reply_forward(msg Message, mut r redisclient.Redis, value string) ? {
	// reply have only one destination (source)
	dst := msg.twin_dst[0]

	println('resolving twin: $dst')
	mut dest := ctx.resolver(u32(dst)) or {
		println('unknown twin, drop')
		return
	}

	/*
	dest := twins[dst]

	if dest == "" {
		println("unknown twin, drop")
		return
	}
	*/

	println('[+] forwarding reply to $dest')

	// forward to reply agent
	response := http.post('http://$dest:8051/zbus-reply', value) or {
		println(err)
		http.Response{}
	}

	println(response)
}

fn (mut ctx MBusSrv) handle_from_reply_for_me(msg Message, mut r redisclient.Redis, value string) ? {
	println('[+] message reply for me, fetching backlog')

	retval := r.hget('msgbus.system.backlog', msg.id) ?
	original := json.decode(Message, retval) or {
		println('original decode failed')
		return
	}

	mut update := json.decode(Message, value) or {
		println('update decode failed')
		return
	}

	// restore return queue name for the caller
	update.retqueue = original.retqueue

	// forward reply to original sender
	r.lpush(update.retqueue, json.encode(update)) ?

	// remove from backlog
	r.hdel('msgbus.system.backlog', msg.id) ?
}

fn (mut ctx MBusSrv) handle_from_reply(mut r redisclient.Redis, value string) ? {
	msg := json.decode(Message, value) or {
		println('decode failed')
		return
	}

	ctx.debug(msg.str())

	msg.validate() or {
		println('reply: could not validate input')
		println(err)
		return
	}

	if msg.twin_dst[0] == ctx.myid {
		ctx.handle_from_reply_for_me(msg, mut r, value) ?
	} else if msg.twin_src == ctx.myid {
		ctx.handle_from_reply_forward(msg, mut r, value) ?
	}
}

fn (mut ctx MBusSrv) handle_from_remote(mut r redisclient.Redis, value string) ? {
	msg := json.decode(Message, value) or {
		println('decode failed')
		return
	}

	// println(msg)

	msg.validate() or {
		println('remote: could not validate input')
		println(err)
		return
	}

	println('[+] forwarding to local service: msgbus.' + msg.command)

	// forward to local service
	r.lpush('msgbus.' + msg.command, value) ?
}

fn (mut ctx MBusSrv) request_needs_retry(msg Message, mut update Message, mut r redisclient.Redis) ? {
	println('[-] could not send message to remote msgbus')

	// restore 'update' to original state
	update.retqueue = msg.retqueue

	if update.retry == 0 {
		println('[-] no more retry, replying with error')
		update.err = 'could not send request and all retries done'
		output := json.encode(update)
		r.lpush(update.retqueue, output) ?
		return
	}

	println('[-] retry set to $update.retry, adding to retry list')

	// remove one retry
	update.retry -= 1
	update.epoch = time.now().unix_time()

	value := json.encode(update)
	r.hset('msgbus.system.retry', update.id, value) ?
}

fn (mut ctx MBusSrv) handle_from_local_prepare_item(msg Message, mut r redisclient.Redis, value string, dst int) ? {
	mut update := json.decode(Message, value) or {
		println('decode failed')
		return
	}

	update.twin_src = ctx.myid
	update.twin_dst = [dst]

	ctx.debug('[+] resolving twin: $dst')

	mut dest := ctx.resolver(u32(dst)) or {
		println('unknown twin')
		update.err = 'unknown twin destination'
		output := json.encode(update)
		r.lpush(update.retqueue, output) ?
		return
	}

	/*
	dest := twins[dst]

	if dest == "" {
		println("unknown twin")
		update.err = "unknown twin destination"
		output := json.encode(update)
		r.lpush(update.retqueue, output)?
		continue
	}
	*/

	id := r.incr('msgbus.counter.$dst') ?

	update.id = '${dst}.$id'
	update.retqueue = 'msgbus.system.reply'

	ctx.debug('[+] forwarding to $dest')

	output := json.encode(update)
	response := http.post('http://$dest:8051/zbus-remote', output) or {
		eprintln(err)
		ctx.request_needs_retry(msg, mut update, mut r) ?
		return
	}

	ctx.debug('[+] message sent to target msgbus')
	ctx.debug(response.str())

	/*
	LEGACY
	mut rr := redisclient.connect(dest)?
	output := json.encode(update)
	rr.lpush("msgbus.system.remote", output)?
	rr.socket.close()?
	*/

	// keep message sent into backlog
	// needed to find back return queue etc.
	r.hset('msgbus.system.backlog', update.id, value) ?
}

fn (mut ctx MBusSrv) handle_from_local_prepare(msg Message, mut r redisclient.Redis, value string) ? {
	ctx.debug('original return queue: $msg.retqueue')

	for dst in msg.twin_dst {
		ctx.handle_from_local_prepare_item(msg, mut r, value, dst) ?
	}
}

fn (mut ctx MBusSrv) handle_from_local_return(msg Message, mut r redisclient.Redis, value string) ? {
	println('---')
}

fn (mut ctx MBusSrv) handle_from_local(mut r redisclient.Redis, value string) ? {
	msg := json.decode(Message, value) or {
		println('decode failed')
		return
	}

	msg.validate() or {
		println('local: could not validate input')
		println(err)
		return
	}

	ctx.debug(msg.str())

	if msg.id == '' {
		ctx.handle_from_local_prepare(msg, mut r, value) ?
	} else {
		// FIXME: not used, not needed ?
		ctx.handle_from_local_return(msg, mut r, value) ?
	}
}

fn (mut ctx MBusSrv) handle_internal_hgetall(lines []resp2.RValue) []HSetEntry {
	mut entries := []HSetEntry{}

	// build usable list from redis response
	for i := 0; i < lines.len; i += 2 {
		value := resp2.get_redis_value(lines[i + 1])
		message := json.decode(Message, value) or {
			println('decode failed hgetall message')
			continue
		}

		entries << HSetEntry{
			key: resp2.get_redis_value(lines[i])
			value: message
		}
	}

	return entries
}

fn (mut ctx MBusSrv) handle_scrubbing(mut r redisclient.Redis) ? {
	ctx.debug('[+] scrubbing')

	lines := r.hgetall('msgbus.system.backlog') ?
	mut entries := ctx.handle_internal_hgetall(lines)

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

			r.lpush(entry.value.retqueue, output) ?
			r.hdel('msgbus.system.backlog', entry.key) ?
		}
	}
}

fn (mut ctx MBusSrv) handle_retry(mut r redisclient.Redis) ? {
	ctx.debug('[+] checking retries')

	lines := r.hgetall('msgbus.system.retry') ?
	mut entries := ctx.handle_internal_hgetall(lines)

	now := time.now().unix_time()

	// iterate over each entries
	for mut entry in entries {
		if now > entry.value.epoch + 5 { // 5 sec debug
			println('[+] retry needed: $entry.key')

			value := json.encode(entry.value)

			// remove from retry list
			r.hdel('msgbus.system.retry', entry.key) ?

			// re-call sending function, which will succeed
			// or put it back to retry
			ctx.handle_from_local_prepare_item(entry.value, mut r, value, entry.value.twin_dst[0]) ?
		}
	}
}

fn (ctx MBusSrv) debug(msg string) {
	if ctx.debugval > 0 {
		println(msg)
	}
}
