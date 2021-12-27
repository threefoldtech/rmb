module server

import json
import time
import vweb
import net.http
import despiegk.crystallib.resp2
import despiegk.crystallib.redisclient
import threefoldtech.vgrid.tfgriddb

pub struct Message {
pub mut:
	version int [json: ver]       // protocol version, used for update
	id string [json: uid]         // unique identifier set by server
	command string [json: cmd]    // command to request in dot notation
	expiration int [json: exp]    // expiration in seconds, based on epoch
	retry int [json: try]         // amount of retry if remote is unreachable
	data string [json: dat]       // binary payload to send to remote, base64 encoded
	twin_src int [json: src]      // twinid source, will be set by server
	twin_dst []int [json: dst]    // twinid of destination, can be more than one
	retqueue string [json: ret]   // return queue name where to send reply
	schema string [json: shm]     // schema to define payload, later could enforce payload
	epoch i64 [json: now]         // unix timestamp when request were created
	err string [json: err]        // optional error message if any
}

pub struct HSetEntry {
	key string
mut:
	value Message
}

struct MBusSrv {
mut:
	debug    int        // debug level
	raddr    string     // redis address
	myid     int         // local twin id
	subaddr  string   // substrate (graphql) url
	grid     tfgriddb.Explorer
}

struct App {
	vweb.Context
mut:
	redis redisclient.Redis
	config shared MBusSrv
}

fn (msg Message) validate() ? {
	if msg.version != 1 {
		return error("protocol version mismatch")
	}

	if msg.command == "" {
		return error("missing command request")
	}

	if msg.twin_dst.len == 0 {
		return error("missing twin destination")
	}

	if msg.retqueue == "" {
		return error("return queue not defined")
	}
}

fn (mut ctx MBusSrv) handle_from_reply_forward(msg Message, mut r redisclient.Redis, value string) ? {
	// reply have only one destination (source)
	dst := msg.twin_dst[0]

	println("resolving twin: $dst")
	mut dest := ctx.resolver(u32(dst)) or {
		println("unknown twin, drop")
		return
	}

	/*
	dest := twins[dst]

	if dest == "" {
		println("unknown twin, drop")
		return
	}
	*/

	println("[+] forwarding reply to $dest")

	// forward to reply agent
	response := http.post("http://$dest:8051/zbus-reply", value) or {
		println(err)
		http.Response{}
	}

	println(response)
}

fn (mut ctx MBusSrv) handle_from_reply_for_me(msg Message, mut r redisclient.Redis, value string) ? {
	println("[+] message reply for me, fetching backlog")

	retval := r.hget("msgbus.system.backlog", msg.id)?
	original := json.decode(Message, retval) or {
		println("original decode failed")
		return
	}

	mut update := json.decode(Message, value) or {
		println("update decode failed")
		return
	}

	// restore return queue name for the caller
	update.retqueue = original.retqueue

	// forward reply to original sender
	r.lpush(update.retqueue, json.encode(update))?

	// remove from backlog
	r.hdel("msgbus.system.backlog", msg.id)?
}

fn (mut ctx MBusSrv) handle_from_reply(mut r redisclient.Redis, value string) ? {
	msg := json.decode(Message, value) or {
		println("decode failed")
		return
	}

	if ctx.debug > 0 {
		println(msg)
	}

	msg.validate() or {
		println("reply: could not validate input")
		println(err)
		return
	}

	if msg.twin_dst[0] == ctx.myid {
		ctx.handle_from_reply_for_me(msg, mut r, value)?

	} else if msg.twin_src == ctx.myid {
		ctx.handle_from_reply_forward(msg, mut r, value)?
	}
}


fn (mut ctx MBusSrv) handle_from_remote(mut r redisclient.Redis, value string) ? {
	msg := json.decode(Message, value) or {
		println("decode failed")
		return
	}

	// println(msg)

	msg.validate() or {
		println("remote: could not validate input")
		println(err)
		return
	}

	println("[+] forwarding to local service: msgbus." + msg.command)

	// forward to local service
	r.lpush("msgbus." + msg.command, value)?
}

fn (mut ctx MBusSrv) request_needs_retry(msg Message, mut update Message, mut r redisclient.Redis) ? {
	println("[-] could not send message to remote msgbus")

	// restore 'update' to original state
	update.retqueue = msg.retqueue

	if update.retry == 0 {
		println("[-] no more retry, replying with error")
		update.err = "could not send request and all retries done"
		output := json.encode(update)
		r.lpush(update.retqueue, output)?
		return
	}

	println("[-] retry set to $update.retry, adding to retry list")

	// remove one retry
	update.retry -= 1
	update.epoch = time.now().unix_time()

	value := json.encode(update)
	r.hset("msgbus.system.retry", update.id, value)?
}

fn (mut ctx MBusSrv) handle_from_local_prepare_item(msg Message, mut r redisclient.Redis, value string, dst int) ? {
	mut update := json.decode(Message, value) or {
		println("decode failed")
		return
	}

	update.twin_src = ctx.myid
	update.twin_dst = [dst]

	if ctx.debug > 0 {
		println("[+] resolving twin: $dst")
	}

	mut dest := ctx.resolver(u32(dst)) or {
		println("unknown twin")
		update.err = "unknown twin destination"
		output := json.encode(update)
		r.lpush(update.retqueue, output)?
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

	id := r.incr("msgbus.counter.$dst")?

	update.id = "${dst}.${id}"
	update.retqueue = "msgbus.system.reply"

	if ctx.debug > 0 {
		println("[+] forwarding to $dest")
	}

	output := json.encode(update)
	response := http.post("http://$dest:8051/zbus-remote", output) or {
		eprintln(err)
		ctx.request_needs_retry(msg, mut update, mut r)?
		return
	}

	if ctx.debug > 0 {
		println("[+] message sent to target msgbus")
		println(response)
	}

	/* LEGACY
	mut rr := redisclient.connect(dest)?
	output := json.encode(update)
	rr.lpush("msgbus.system.remote", output)?
	rr.socket.close()?
	*/

	// keep message sent into backlog
	// needed to find back return queue etc.
	r.hset("msgbus.system.backlog", update.id, value)?
}

fn (mut ctx MBusSrv) handle_from_local_prepare(msg Message, mut r redisclient.Redis, value string) ? {
	if ctx.debug > 0 {
		println("original return queue: $msg.retqueue")
	}

	for dst in msg.twin_dst {
		ctx.handle_from_local_prepare_item(msg, mut r, value, dst)?
	}
}

fn (mut ctx MBusSrv) handle_from_local_return(msg Message, mut r redisclient.Redis, value string) ? {
	println("---")
}

fn (mut ctx MBusSrv) handle_from_local(mut r redisclient.Redis, value string) ? {
	msg := json.decode(Message, value) or {
		println("decode failed")
		return
	}

	msg.validate() or {
		println("local: could not validate input")
		println(err)
		return
	}

	if ctx.debug > 0 {
		println(msg)
	}

	if msg.id == "" {
		ctx.handle_from_local_prepare(msg, mut r, value)?
	} else {
		// FIXME: not used, not needed ?
		ctx.handle_from_local_return(msg, mut r, value)?
	}
}

fn (mut ctx MBusSrv) handle_internal_hgetall(lines []resp2.RValue) []HSetEntry {
	mut entries := []HSetEntry{}

	// build usable list from redis response
	for i := 0; i < lines.len; i += 2 {
		value := resp2.get_redis_value(lines[i + 1])
		message := json.decode(Message, value) or {
			println("decode failed hgetall message")
			continue
		}

		entries << HSetEntry{
			key: resp2.get_redis_value(lines[i]),
			value: message
		}
	}

	return entries
}

fn (mut ctx MBusSrv) handle_scrubbing(mut r redisclient.Redis) ? {
	if ctx.debug > 0 {
		println("[+] scrubbing")
	}

	lines := r.hgetall("msgbus.system.backlog")?
	mut entries := ctx.handle_internal_hgetall(lines)

	now := time.now().unix_time()

	// iterate over each entries
	for mut entry in entries {
		if entry.value.expiration == 0 {
			// avoid infinite expiration, fallback to 1h
			entry.value.expiration = 3600
		}

		if entry.value.epoch + entry.value.expiration < now {
			if ctx.debug > 0 {
				println("[+] expired: $entry.key")
			}

			entry.value.err = "request timeout (expiration reached, $entry.value.expiration seconds)"
			output := json.encode(entry.value)

			r.lpush(entry.value.retqueue, output)?
			r.hdel("msgbus.system.backlog", entry.key)?
		}
	}
}

fn (mut ctx MBusSrv) handle_retry(mut r redisclient.Redis) ? {
	if ctx.debug > 0 {
		println("[+] checking retries")
	}

	lines := r.hgetall("msgbus.system.retry")?
	mut entries := ctx.handle_internal_hgetall(lines)

	now := time.now().unix_time()

	// iterate over each entries
	for mut entry in entries {
		if now > entry.value.epoch + 5 { // 5 sec debug
			println("[+] retry needed: $entry.key")

			value := json.encode(entry.value)

			// remove from retry list
			r.hdel("msgbus.system.retry", entry.key)?

			// re-call sending function, which will succeed
			// or put it back to retry
			ctx.handle_from_local_prepare_item(entry.value, mut r, value, entry.value.twin_dst[0])?
		}
	}
}

fn (mut ctx MBusSrv) resolver(twinid u32) ? string {
	twin := ctx.grid.twin_by_id(twinid)?
	return twin.ip
}

fn runweb(config MBusSrv) {
	app := App{
		config: config,
	}

	vweb.run(app, 8051)
}

pub fn run_server(myid int, redis_addres string, substrate string, debug int) ? {
	mut grid := tfgriddb.explorer_new()?

	mut srv := MBusSrv{
		myid: myid,
		raddr: redis_addres,
		debug: debug,
		subaddr: substrate,
		grid: grid,
	}

	println("[+] twin id: $myid")

	println('[+] initializing agent server')
	go runweb(srv)

	println("[+] connecting to redis: $srv.raddr")
	mut r := redisclient.connect(srv.raddr)?
	r.ping() or {
		println("[-] could not connect to redis server")
		println(err)
		exit(1)
	}

	println("[+] substrate url: $srv.subaddr")

	println("[+] server: waiting requests")

	for {
		if srv.debug > 0 {
			println("[+] cycle waiting")
		}

		m := r.blpop(["msgbus.system.local", "msgbus.system.remote", "msgbus.system.reply"], "1")?

		if m.len == 0 {
			srv.handle_scrubbing(mut r)?
			srv.handle_retry(mut r)?
			continue
		}

		value := resp2.get_redis_value(m[1])

		if resp2.get_redis_value(m[0]) == "msgbus.system.reply" {
			srv.handle_from_reply(mut r, value)?
		}

		if resp2.get_redis_value(m[0]) == "msgbus.system.local" {
			srv.handle_from_local(mut r, value)?
		}

		if resp2.get_redis_value(m[0]) == "msgbus.system.remote" {
			srv.handle_from_remote(mut r, value)?
		}
	}
}

['/zbus-remote'; post]
pub fn (mut app App) zbus_web_remote() vweb.Result {
	if app.config.debug > 0 {
		println("[+] request from external agent")
		println(app.req.data)
	}

	_ := json.decode(Message, app.req.data) or {
		return app.json('{"status": "error", "error": "could not parse message request"}')
	}

	// FIXME: could not create redis single time via init_server for some reason
	lock app.config {
		mut redis := redisclient.connect(app.config.raddr) or { panic(err) }

		// forward request to local redis
		redis.lpush("msgbus.system.remote", app.req.data) or { panic(err) }
		redis.socket.close() or { panic(err) }
	}

	return app.json('{"status": "accepted"}')
}

['/zbus-reply'; post]
pub fn (mut app App) zbus_web_reply() vweb.Result {
	if app.config.debug > 0 {
		println("[+] reply from external agent")
		println(app.req.data)
	}

	_ := json.decode(Message, app.req.data) or {
		return app.json('{"status": "error", "error": "could not parse message request"}')
	}

	lock app.config {
		// FIXME: could not create redis single time via init_server for some reason
		mut redis := redisclient.connect(app.config.raddr) or { panic(err) }

		// forward request to local redis
		redis.lpush("msgbus.system.reply", app.req.data) or { panic(err) }
		redis.socket.close() or { panic(err) }
	}

	return app.json('{"status": "accepted"}')
}

