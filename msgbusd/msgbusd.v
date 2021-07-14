module main

import threefoldtech.rmb.server
import os.cmdline
import os

fn main() {
	cmd_twin := cmdline.option(os.args, "--twin", "")
	cmd_redis := cmdline.option(os.args, "--redis", "127.0.0.1:6379")
	cmd_sub := cmdline.option(os.args, "--substrate", "https://explorer.devnet.grid.tf/")
	cmd_debug := cmdline.option(os.args, "--debug", "none")

	if cmd_twin == "" {
		println("Usage: msgbusd <options>")
		println("")
		println("  --twin       <twin-id>")
		println("  --redis      [redis-host-port-socket]")
		println("  --substrate  [substrate-http-baseurl]")
		println("  --debug      [none or all]")
		println("")
		println("  [required] --twin local twin id")
		println("  [optional] --redis target can be host:port or unix socket path")
		println("  [optional] --substrate alternative base url can be specified")
		println("  [optional] --debug none or all to enable extra debug")
		println("")
		exit(1)
	}

	myid := cmd_twin.int()
	mut debug := 0

	if cmd_debug == "all" {
		debug = 1
	}

	server.run_server(myid, cmd_redis, cmd_sub, debug) or { panic("Can't run msgbus server: $err") }
}
