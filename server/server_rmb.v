module server

import despiegk.crystallib.resp2


//is the main loop getting info from the redis and making sure it gets processed
fn (mut srv MBusSrv) run_rmb()? {
	println('[+] initializing agent server')
	go srv.run_web()

	println("[+] twin id: $srv.myid")

	mut r := srv.redis
	r.ping() or {
		return error("[-] could not connect to redis server.'n$err")
	}

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
