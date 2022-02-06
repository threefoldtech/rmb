module server

import json
import time
import vweb
import net.http
import despiegk.crystallib.resp2
import despiegk.crystallib.redisclient
import threefoldtech.vgrid.explorer

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
	debugval int        // debug level
	raddr    string     // redis address
	myid     int        // local twin id
	grid     &explorer.ExplorerConnection
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

fn (ctx MBusSrv) debug(msg string) {
	if ctx.debugval > 0 {
		println(msg)
	}
}


fn (mut ctx MBusSrv) resolver(twinid u32) ? string {
	twin := ctx.grid.twin_by_id(twinid)?
	return twin.ip
}


//tfgridnet is test,dev or main
pub fn run_server(myid int, redis_addres string, tfgridnet string, debug int) ? {

	tfgridnet2 := match tfgridnet {
		'main'{ explorer.TFGridNet.main }
		'test'{ explorer.TFGridNet.test }
		'dev'{ explorer.TFGridNet.dev }
		else { explorer.TFGridNet.test}
	}

	mut explorer := explorer.get(tfgridnet2)

	mut srv := MBusSrv{
		myid: myid,
		raddr: redis_addres,
		debugval: debug,
		grid: explorer,
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

	println("[+] tfgrid net: $tfgridnet2")

	println("[+] server: waiting requests")

	for {
		srv.debug("[+] cycle waiting")

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
