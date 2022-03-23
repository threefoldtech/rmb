module main

import threefoldtech.rmb.server
import despiegk.crystallib.console
import os.cmdline
import os

const max_workers = 10

const default_workers = 4
const options = ['--twin', '--tfgridnet', '--log-level', '--workers']
fn main() {
	mut logger := console.Logger{}
	usage := r"Usage: msgbusd <options>

  --twin       <twin-id>
  --tfgridnet  [dev,test or main]
  --log-level  [debug, info, warning, error]
  --workers    <number of threads used>

  [required] --twin 		local twin id
  [optional] --tfgridnet 	choose network environment 	default test
  [optional] --log-level 	set log level 	default error
  [optional] --workers 		number of threads used, 1 to $max_workers  default $default_workers
	
"
	for arg in cmdline.only_options(os.args) {
		if arg !in options {
			logger.error('Unknown arg $arg, please check usage info.')
			println(usage)
			return
		}
	}
	cmd_twin := cmdline.option(os.args, '--twin', '')
	cmd_network := cmdline.option(os.args, '--tfgridnet', 'test')
	cmd_log_level := cmdline.option(os.args, '--log-level', 'error')
	cmd_workers := cmdline.option(os.args, '--workers', '$default_workers')

	if cmd_twin == '' {
		println(usage)
		exit(1)
	}

	if cmd_log_level !in ['debug', 'info', 'warning', 'error'] {
		logger.error('Unknown log level, please choose from [debug, info, warning, error]')
		println(usage)
		return
	}
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
	workers := cmd_workers.int()

	if workers < 1 || workers > max_workers {
		logger.error('MSGBUS could work with at least 1 and up to $max_workers workers only')
		println(usage)
		return
	}

	if cmd_network !in ['dev', 'test', 'main'] {
		logger.error('Unknown network, please choose from [dev, test, main]')
		println(usage)
		return
	}

	server.run_server(myid, cmd_network, workers, logger) or {
		logger.critical("Can't run msgbus server: $err")
		return
	}
}
