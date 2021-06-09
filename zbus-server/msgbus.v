module main

// import crypto.md5
import json
import os
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
	epoch int [json: now]         // unix timestamp when request were created
	err string [json: err]        // optional error message if any
}

pub struct HSetEntry {
	key string
mut:
	value Message
}

struct App {
	vweb.Context
mut:
	redis redisclient.Redis
}

fn handle_from_reply_forward(msg Message, mut r redisclient.Redis, value string, twins map[int]string) ? {
	// reply have only one destination (source)
	dst := msg.twin_dst[0]

	println("resolving twin: $dst")
	mut dest := resolver(u32(dst)) or {
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

	println("forwarding reply to $dest")

	// forward to reply agent
	response := http.post("http://$dest:8051/zbus-reply", value) or {
		println(err)
		http.Response{}
	}

	println(response)
}

fn handle_from_reply_for_me(msg Message, mut r redisclient.Redis, value string, twins map[int]string) ? {
	println("message reply for me, fetching backlog")

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

fn handle_from_reply(mut r redisclient.Redis, value string, twins map[int]string, myid int) ? {
	msg := json.decode(Message, value) or {
		println("decode failed")
		return
	}

	println(msg)

	if msg.twin_dst[0] == myid {
		handle_from_reply_for_me(msg, mut r, value, twins)?

	} else if msg.twin_src == myid {
		handle_from_reply_forward(msg, mut r, value, twins)?
	}
}


fn handle_from_remote(mut r redisclient.Redis, value string, twins map[int]string) ? {
	msg := json.decode(Message, value) or {
		println("decode failed")
		return
	}

	println(msg)

	println("forwarding to local service: msgbus." + msg.command)

	// forward to local service
	r.lpush("msgbus." + msg.command, value)?
}

fn handle_from_local_prepare(msg Message, mut r redisclient.Redis, value string, twins map[int]string, myid int) ? {
	println("original return queue: $msg.retqueue")

	for dst in msg.twin_dst {
		mut update := json.decode(Message, value) or {
			println("decode failed")
			return
		}

		update.twin_src = myid
		update.twin_dst = [dst]

		println("resolving twin: $dst")
		mut dest := resolver(u32(dst)) or {
			println("unknown twin")
			update.err = "unknown twin destination"
			output := json.encode(update)
			r.lpush(update.retqueue, output)?
			continue
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

		println("forwarding to $dest")

		output := json.encode(update)
		response := http.post("http://$dest:8051/zbus-remote", output) or {
			println(err)
			http.Response{}
		}

		// FIXME: support retry here
		println(response)

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
}

fn handle_from_local_return(msg Message, mut r redisclient.Redis, value string, twins map[int]string, myid int) ? {
	println("---")
}

fn handle_from_local(mut r redisclient.Redis, value string, twins map[int]string, myid int) ? {
	msg := json.decode(Message, value) or {
		println("decode failed")
		return
	}

	println(msg)

	if msg.id == "" {
		handle_from_local_prepare(msg, mut r, value, twins, myid)?
	} else {
		// FIXME: not used, not needed ?
		handle_from_local_return(msg, mut r, value, twins, myid)?
	}
}

fn handle_scrubbing(mut r redisclient.Redis) ? {
	lines := r.hgetall("msgbus.system.backlog")?
	mut entries := []HSetEntry{}

	// build usable list from redis response
	for i := 0; i < lines.len; i += 2 {
		value := resp2.get_redis_value(lines[i + 1])
		message := json.decode(Message, value) or {
			println("decode failed scrubbing")
			continue
		}

		entries << HSetEntry{
			key: resp2.get_redis_value(lines[i]),
			value: message
		}
	}

	now := time.now().unix_time()

	// iterate over each entries
	for mut entry in entries {
		if entry.value.expiration == 0 {
			// avoid infinite expiration, fallback to 1h
			entry.value.expiration = 3600
		}

		if entry.value.epoch + entry.value.expiration > now {
			println("[+] expired: $entry.key")

			entry.value.err = "request timeout (expiration reached, $entry.value.expiration seconds)"
			output := json.encode(entry.value)

			r.lpush(entry.value.retqueue, output)?
			r.hdel("msgbus.system.backlog", entry.key)?
		}
	}
}

fn resolver(twinid u32) ? string {
	mut db := tfgriddb.tfgrid_new()?
	twin := db.twin_get_by_id(twinid)?

	if twin.id == 0 {
		return error("twin not found")
	}

	return twin.ip
}

fn main() {
	mut myid := 1000

	if os.args.len > 1 {
		println("[+] twin id is user defined")
		myid = os.args[1].int()

	} else {
		println("[-] twin id not specified, fallback")
		myid = 1001
	}

	println("[+] twin id: $myid")

	mut twins := map[int]string{}

	twins[1001] = "127.0.0.1:8051"
	twins[1002] = "127.0.0.1:8051"

	if twins[myid] == "" {
		println("unknown twin id for redis listening")
	}

	println('[+] initializing agent server')
	go fn() {
		vweb.run(&App{}, 8051)
	}()


	mut r := redisclient.connect("127.0.0.1:6379")?

	for {
		println("waiting message")
		m := r.blpop(["msgbus.system.local", "msgbus.system.remote", "msgbus.system.reply"], "1")?

		if m.len == 0 {
			handle_scrubbing(mut r)?
			continue
		}

		value := resp2.get_redis_value(m[1])

		if resp2.get_redis_value(m[0]) == "msgbus.system.reply" {
			handle_from_reply(mut r, value, twins, myid)?
		}

		if resp2.get_redis_value(m[0]) == "msgbus.system.local" {
			handle_from_local(mut r, value, twins, myid)?
		}

		if resp2.get_redis_value(m[0]) == "msgbus.system.remote" {
			handle_from_remote(mut r, value, twins)?
		}
	}
}

['/zbus-remote'; post]
pub fn (mut app App) zbus_web_remote() vweb.Result {
	println("[+] request from external agent")
	println(app.req.data)

	_ := json.decode(Message, app.req.data) or {
		return app.json('{"status": "error", "error": "could not parse message request"}')
	}

	// FIXME: could not create redis single time via init_server for some reason
	app.redis = redisclient.connect("127.0.0.1:6379") or { panic(err) }

	// forward request to local redis
	app.redis.lpush("msgbus.system.remote", app.req.data) or { panic(err) }
	app.redis.socket.close() or { panic(err) }

	return app.json('{"status": "accepted"}')
}

['/zbus-reply'; post]
pub fn (mut app App) zbus_web_reply() vweb.Result {
	println("[+] reply from external agent")
	println(app.req.data)

	_ := json.decode(Message, app.req.data) or {
		return app.json('{"status": "error", "error": "could not parse message request"}')
	}

	// FIXME: could not create redis single time via init_server for some reason
	app.redis = redisclient.connect("127.0.0.1:6379") or { panic(err) }

	// forward request to local redis
	app.redis.lpush("msgbus.system.reply", app.req.data) or { panic(err) }
	app.redis.socket.close() or { panic(err) }

	return app.json('{"status": "accepted"}')
}

