module main

import threefoldtech.rmb.server
import os.cmdline
import os

const max_workers = 100

fn main() {
	cmd_twin := cmdline.option(os.args, '--twin', '')
	cmd_network := cmdline.option(os.args, '--tfgridnet', 'test')
	cmd_debug := cmdline.option(os.args, '--debug', 'none')
	cmd_workers := cmdline.option(os.args, '--workers', '10')

	if cmd_twin == '' {
		println('Usage: msgbusd <options>')
		println('')
		println('  --twin       <twin-id>')
		println('  --tfgridnet  [dev,test or main]')
		println('  --debug      [none or all]')
		println('  --workers    <number of threads used>')
		println('')
		println('  [required] --twin 		local twin id')
		println('  [optional] --debug 		none or all to enable extra debug')
		println('  [optional] --tfgridnet 	choose network environment')
		println('  [optional] --workers 		number of threads used, limited to $max_workers')
		println('')
		exit(1)
	}

	myid := cmd_twin.int()
	mut workers := if cmd_workers.int() == 0 { 10 } else { cmd_workers.int() }

	if workers > max_workers {
		println('MSGBUS will work with $max_workers workers only')
		workers = 100
	}

	mut debug := 0

	if cmd_debug == 'all' {
		debug = 1
	}

	if cmd_network !in ['dev', 'test', 'main'] {
		println('Unknown network, please choose from [dev, test, main]')
		return
	}

	server.run_server(myid, cmd_network, workers, debug) or {
		panic("Can't run msgbus server: $err")
	}
}
