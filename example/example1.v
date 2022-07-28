module main

import threefoldtech.rmb.server
import time

// fn do()?{

// }

fn main() {

	server.run_server(2, , cmd_network, true) or { panic("Can't run msgbus server: $err") }

	for {
		time.sleep(1000)
	}
}
