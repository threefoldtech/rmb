module server

import despiegk.crystallib.resp2
import json

// is the main loop getting info from the redis and making sure it gets processed
fn (mut srv MBusSrv) run_rmb() ? {
	println('[+] initializing agent server')
	go srv.run_web()

	println('[+] twin id: $srv.myid')

	mut r := srv.redis
	r.ping() or { return error("[-] could not connect to redis server.'n$err") }

	println('[+] server: waiting requests')

	for {
		// srv.debug('[+] cycle waiting')

		m := r.blpop(['msgbus.system.local', 'msgbus.system.remote', 'msgbus.system.reply'],
			'1') ?

		if m.len == 0 {
			srv.handle_scrubbing() or { eprintln('error happen while handle scrubbing, $err') }
			srv.handle_retry() or { eprintln('error happen while handle retry, $err') }
			continue
		}

		key := resp2.get_redis_value(m[0])
		value := resp2.get_redis_value(m[1])
		mut msg := json.decode(Message, value) or {
			return error('failed to decode message with error: $err')
		}
		if key == 'msgbus.system.reply' {
			srv.handle_from_reply(mut msg) or { eprintln('error from (handle_from_reply), $err') }
		}

		if key == 'msgbus.system.local' {
			srv.handle_from_local(mut msg) or { eprintln('error from (handle_from_local), $err') }
		}

		if key == 'msgbus.system.remote' {
			srv.handle_from_remote(mut msg) or { eprintln('error from (handle_from_remote), $err') }
		}
	}
}
