module main

import threefoldtech.rmb.server
import os.cmdline
import os
import time

fn main() {
	cmd_twin := cmdline.option(os.args, '--twin', '')
	cmd_redis := cmdline.option(os.args, '--redis', '127.0.0.1:6379')
	cmd_network := cmdline.option(os.args, '--tfgridnet', 'test')
	cmd_debug := cmdline.option(os.args, '--debug', 'none')

	if cmd_twin == '' {
		println('Usage: msgbusd <options>')
		println('')
		println('  --twin       <twin-id>')
		println('  --redis      [redis-host-port-socket]')
		println('  --tfgridnet  [dev,test or main]')
		println('  --debug      [none or all]')
		println('')
		println('  [required] --twin local twin id')
		println('  [optional] --redis target can be host:port or unix socket path')
		println('  [optional] --debug none or all to enable extra debug')
		println('  [optional] --network choose network environment')
		println('')
		exit(1)
	}

	myid := cmd_twin.int()
	mut debug := 0

	if cmd_debug == 'all' {
		debug = 1
	}


	if cmd_sub.starts_with('ws') {
		eprintln('Cannot use websocket substrate, https graphql required')
		eprintln('Eg: https://graphql.dev.grid.tf/graphql')
		exit(1)
	}

	server.run_server(myid, cmd_redis, cmd_network, debug) or { panic("Can't run msgbus server: $err") }

	for {
		time.sleep(1000)
	}
}
