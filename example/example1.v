module main

import threefoldtech.rmb.server
import time

fn do()?{

}

fn main() {

	server.run_server(myid, cmd_redis, cmd_network, debug) or { panic("Can't run msgbus server: $err") }

	for {
		time.sleep(1000)
	}
}
