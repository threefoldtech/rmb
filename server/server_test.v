import threefoldtech.rmb.server
import os

fn test_server() {
	mut myid := 1000

	if os.args.len > 1 {
		println("[+] twin id is user defined")
		myid = os.args[1].int()

	} else {
		println("[-] missing twinid, you have to specify it")
		exit(1)
	}

	if os.args.len > 2 {
		redis_addr = os.args[2]
	}

	server.run_server(myid, redis_addr) or { panic("Can't run msgbus server with error $err") }
}
