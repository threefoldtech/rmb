module server

// import vweb
import despiegk.crystallib.resp2
// import threefoldtech.vgrid.explorer


//is the main loop getting info from the redis and making sure it gets processed
fn run_rmb(myid int, tfgridnet string, debug int)? {

	mut srv := srvconfig_get(myid,tfgridnet,debug)?

	println('[+] initializing agent server')

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
