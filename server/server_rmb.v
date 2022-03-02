module server

import despiegk.crystallib.resp2
import json
import time

// is the main loop getting info from the redis and making sure it gets processed
fn run_rmb(myid int, tfgridnet string, debug int) ? {
	mut srv := srvconfig_get(myid, tfgridnet, debug) ?
	mut r := srv.redis
	r.ping() or { return error("[-] could not connect to redis server.'n$err") }

	for {
		// srv.debug('[+] cycle waiting')
		m := r.blpop(['msgbus.system.local', 'msgbus.system.remote', 'msgbus.system.reply'],
			'0') or {
			eprintln('error happen with main blpop, $err')
			[]resp2.RValue{}
		}

		key := resp2.get_redis_value(m[0])
		value := resp2.get_redis_value(m[1])
		mut msg := json.decode(Message, value) or {
			eprintln('failed to decode message with error: $err')
			continue
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

fn run_scrubbing(myid int, tfgridnet string, debug int) ? {
	println('[+] server: handle scrubbing queue every one second')
	mut srv := srvconfig_get(myid, tfgridnet, debug) ?
	for {
		srv.handle_scrubbing() ?
		time.sleep(time.second)
	}
}

fn run_retry(myid int, tfgridnet string, debug int) ? {
	println('[+] server: handle retry queue every one second')
	mut srv := srvconfig_get(myid, tfgridnet, debug) ?
	for {
		srv.handle_retry() ?
		time.sleep(time.second)
	}
}
