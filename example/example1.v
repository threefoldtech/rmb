module main

import server
import threefoldtech.rmb.server
import freeflowuniverse.crystallib.console
import time
import os
import os.cmdline

// fn do()?{

// }

fn main() {
	mut logger := console.Logger{}
	cmd_network := cmdline.option(os.args, '--tfgridnet', 'test')
	server.run_server(2, cmd_network, 1, logger) or { panic("Can't run msgbus server: $err") }
	for {
		time.sleep(1000)
	}
}
