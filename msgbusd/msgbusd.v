module main

import threefoldtech.rmb.server
import os

fn main() {
	mut myid := 1000
	mut redis_addr := "127.0.0.1:6379"

	if os.args.len > 1 {
		println("[+] twin id is user defined")
		myid = os.args[1].int()

	} else {
		println("Usage: msgbusd <twin-id> [redis-host-port-socket]")
		println("  You need to specify a twin id")
		println("  Redis target can be host:port or unix socket path")
		exit(1)
	}

	if os.args.len > 2 {
		redis_addr = os.args[2]
	}

	server.run_server(myid, redis_addr) or { panic("Can't run msgbus server: $err") }
}
