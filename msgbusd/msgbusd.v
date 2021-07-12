module main

import threefoldtech.rmb.server
import os.cmdline
import os

fn main() {
	cmd_twin := cmdline.option(os.args, "--twin", "")
	cmd_redis := cmdline.option(os.args, "--redis", "127.0.0.1:6379")
	cmd_sub := cmdline.option(os.args, "--substrate", "https://explorer.devnet.grid.tf/")

	if cmd_twin == "" {
		println("Usage: msgbusd <options>")
		println("")
		println("  --twin       <twin-id>")
		println("  --redis      [redis-host-port-socket]")
		println("  --substrate  [substrate-http-baseurl]")
		println("")
		println("  [required] You need to specify a twin id")
		println("  [optional] Redis target can be host:port or unix socket path")
		println("  [optional] Alternative substrate base url can be specified")
		println("")
		exit(1)
	}

	myid := cmd_twin.int()

	server.run_server(myid, cmd_redis, cmd_sub, 0) or { panic("Can't run msgbus server: $err") }
}
