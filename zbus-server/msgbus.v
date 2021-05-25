module main

// import crypto.md5
import json
import os
import despiegk.crystallib.resp2
import despiegk.crystallib.redisclient

pub struct Message {
pub mut:
	version int [json: ver]

	id string [json: uid]
	// dot notation
	command string [json: cmd]
	// expiration in epoch
	expiration int [json: exp]
	// the data = payload which will be send to the twin_dest(s)
	// data []byte
	data string [json: dat]
	twin_src int [json: src]
	// for who is this message meant, can be more than 1
	twin_dst []int [json: dst]
	// where do you want the return message to come to
	// if not specified then its bu
	return_queue string [json: ret]
	// schema as used for data, normally empty but can be used to identify the version of the input to the target processor.method
	schema string [json: shm]
	// creation date in epoch (int)
	epoch int [json: now]

	err string [json: err]
}

fn handle_from_reply_forward(msg Message, mut r redisclient.Redis, value string, twins map[int]string) ? {
	// reply have only one destination (source)
	dst := msg.twin_dst[0]

	println("resolving twin: $dst")
	dest := twins[dst]

	if dest == "" {
		println("unknown twin, drop")
		return
	}

	println("forwarding reply to $dest")

	mut rr := redisclient.connect(dest)?

	// FORWARD
	rr.lpush("msgbus.system.reply", value)?
	rr.socket.close()?
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
	update.return_queue = original.return_queue

	// forward reply to original sender
	r.lpush(update.return_queue, json.encode(update))?
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
	println("original return queue: $msg.return_queue")

	for dst in msg.twin_dst {
		mut update := json.decode(Message, value) or {
			println("decode failed")
			return
		}

		update.twin_src = myid
		update.twin_dst = [dst]

		println("resolving twin: $dst")
		dest := twins[dst]

		if dest == "" {
			println("unknown twin")
			update.err = "unknown twin destination"
			output := json.encode(update)
			r.lpush(update.return_queue, output)?
			continue
		}

		id := r.incr("msgbus.counter.$dst")?

		update.id = "${dst}.${id}"
		update.return_queue = "msgbus.system.reply"

		println("forwarding to $dest")

		mut rr := redisclient.connect(dest)?

		output := json.encode(update)
		rr.lpush("msgbus.system.remote", output)?
		rr.socket.close()?

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
		// not used FIXME
		handle_from_local_return(msg, mut r, value, twins, myid)?
	}
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

	twins[1001] = "127.0.0.1:6379"
	twins[1002] = "127.0.0.1:6372"

	if twins[myid] == "" {
		println("unknown twin id for redis listening")
	}

	mut r := redisclient.connect(twins[myid])?

	for {
		println("waiting message")
		m := r.blpop(["msgbus.system.local", "msgbus.system.remote", "msgbus.system.reply"], "1")?

		if m.len == 0 {
			println("empty")
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
