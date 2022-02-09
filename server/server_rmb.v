module server

import vweb
import despiegk.crystallib.resp2

import threefoldtech.vgrid.explorer



fn run_rmb(srv MBusSrv) {

	println('[+] initializing agent server')

	println("[+] twin id: $srv.myid")
	println("[+] connecting to redis: $srv.raddr")
	mut r := redisclient.connect(srv.raddr)?
	r.ping() or {
		println("[-] could not connect to redis server")
		println(err)
		exit(1)
	}

	println("[+] tfgrid net: $tfgridnet2")

	println("[+] server: waiting requests")

	for {
		srv.debug("[+] cycle waiting")

		m := r.blpop(["msgbus.system.local", "msgbus.system.remote", "msgbus.system.reply"], "1")?

		if m.len == 0 {
			srv.handle_scrubbing(mut r)?
			srv.handle_retry(mut r)?
			continue
		}

		value := resp2.get_redis_value(m[1])

		if resp2.get_redis_value(m[0]) == "msgbus.system.reply" {
			srv.handle_from_reply(mut r, value)?
		}

		if resp2.get_redis_value(m[0]) == "msgbus.system.local" {
			srv.handle_from_local(mut r, value)?
		}

		if resp2.get_redis_value(m[0]) == "msgbus.system.remote" {
			srv.handle_from_remote(mut r, value)?
		}
	}	

}
