module main

import threefoldtech.rmb.server
import os.cmdline
import os
import time

fn main() {
	cmd_twin := cmdline.option(os.args, '--twin', '')
	cmd_network := cmdline.option(os.args, '--tfgridnet', 'test')
	cmd_debug := cmdline.option(os.args, '--debug', 'none')

	if cmd_twin == '' {
		println('Usage: msgbusd <options>')
		println('')
		println('  --twin       <twin-id>')
		println('  --tfgridnet  [dev,test or main]')
		println('  --debug      [none or all]')
		println('')
		println('  [required] --twin 		local twin id')
		println('  [optional] --debug 		none or all to enable extra debug')
		println('  [optional] --tfgridnet 	choose network environment')
		println('')
		exit(1)
	}

	myid := cmd_twin.int()
	mut debug := 0

	if cmd_debug == 'all' {
		debug = 1
	}

	server.run_server(myid, cmd_network, debug) or { panic("Can't run msgbus server: $err") }
}
