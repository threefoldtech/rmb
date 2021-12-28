module main

import threefoldtech.rmb.server
import os.cmdline
import os

fn main() {
	cmd_twin := cmdline.option(os.args, '--twin', '')
	cmd_redis := cmdline.option(os.args, '--redis', '127.0.0.1:6379')
	mut cmd_sub := cmdline.option(os.args, '--substrate', 'https://graphql.dev.grid.tf/graphql')
	cmd_debug := cmdline.option(os.args, '--debug', 'none')
	cmd_network := cmdline.option(os.args, '--network', '')

	if cmd_twin == '' {
		println('Usage: msgbusd <options>')
		println('')
		println('  --twin       <twin-id>')
		println('  --redis      [redis-host-port-socket]')
		println('  --substrate  [substrate-http-baseurl]')
		println('  --debug      [none or all]')
		println('  --network    [dev or test or main]')
		println('')
		println('  [required] --twin local twin id')
		println('  [optional] --redis target can be host:port or unix socket path')
		println('  [optional] --substrate alternative graphql endpoint')
		println('  [optional] --debug none or all to enable extra debug')
		println('  [optional] --network choose network environment to set substrate endpoint easily')
		println('')
		exit(1)
	}

	myid := cmd_twin.int()
	mut debug := 0

	if cmd_debug == 'all' {
		debug = 1
	}

	if cmd_network != '' {
		match cmd_network {
			'dev' {
				cmd_sub = 'https://graphql.dev.grid.tf/graphql'
			}
			'test' {
				cmd_sub = 'https://graphql.test.grid.tf/graphql'
			}
			'main' {
				cmd_sub = 'https://graphql.grid.tf/graphql'
			}
			else {
				eprintln('Unknown network, please choose from [dev, test, main]')
			}
		}
	}

	if cmd_sub.starts_with('ws') {
		eprintln('Cannot use websocket substrate, https graphql required')
		eprintln('Eg: https://graphql.dev.grid.tf/graphql')
		exit(1)
	}

	server.run_server(myid, cmd_redis, cmd_sub, debug) or { panic("Can't run msgbus server: $err") }
}
