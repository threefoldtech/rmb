module main

import threefoldtech.rmb.server
import despiegk.crystallib.console
import os.cmdline
import os

const max_workers = 10

const default_workers = 4

fn main() {
	cmd_twin := cmdline.option(os.args, '--twin', '')
	cmd_network := cmdline.option(os.args, '--tfgridnet', 'test')
	cmd_log_level := cmdline.option(os.args, '--log-level', 'error')
	cmd_workers := cmdline.option(os.args, '--workers', '$default_workers')

	if cmd_twin == '' {
		println('Usage: msgbusd <options>')
		println('')
		println('  --twin       <twin-id>')
		println('  --tfgridnet  [dev,test or main]')
		println('  --log-level  [debug, info, warning, error]')
		println('  --workers    <number of threads used>')
		println('')
		println('  [required] --twin 		local twin id')
		println('  [optional] --tfgridnet 	choose network environment 	default test')
		println('  [optional] --log-level 	set log level 	default error')
		println('  [optional] --workers 		number of threads used, limited to $max_workers')
		println('')
		exit(1)
	}

	mut logger := console.Logger{}
	if cmd_log_level == 'debug' {
		logger.level = .debug
		$if !debug {
			logger.warning('The current binary did not have debug mode, You need to use -g or -d debug in compile time')
		}
	} else if cmd_log_level == 'info' {
		logger.level = .info
	} else if cmd_log_level == 'warning' {
		logger.level = .warning
	}

	myid := cmd_twin.int()
	mut workers := if cmd_workers.int() == 0 { default_workers } else { cmd_workers.int() }

	if workers > max_workers {
		logger.warning('MSGBUS will work with $max_workers workers only')
		workers = max_workers
	}

	if cmd_network !in ['dev', 'test', 'main'] {
		logger.error('Unknown network, please choose from [dev, test, main]')
		return
	}

	server.run_server(myid, cmd_network, workers, logger) or {
		logger.critical("Can't run msgbus server: $err")
		return
	}
}
