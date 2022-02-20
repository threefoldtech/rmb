module server

import json
import vweb
import rand
// import net.http


struct App {
	vweb.Context
mut:
	config MBusSrv [vweb_global]
}



fn (mut srv MBusSrv) run_web()? {
	app := App{
		config: srv,
	}
	vweb.run(app, 8051)
}


['/zbus-remote'; post]
pub fn (mut app App) zbus_web_remote() vweb.Result {

	mut redis := app.config.redis

	if app.config.debugval > 0 {
		println("[+] request from external agent")
		println(app.req.data)
	}

	_ := json.decode(Message, app.req.data) or {
		return app.json('{"status": "error", "error": "could not parse message request"}')
	}

	// forward request to local redis
	redis.lpush("msgbus.system.remote", app.req.data) or {
		return app.json('{"status": "error", "error": "could notsend message to remote"}')
	}

	return app.json('{"status": "accepted"}')
}

['/zbus-reply'; post]
pub fn (mut app App) zbus_web_reply() vweb.Result {
	
	mut redis := app.config.redis

	if app.config.debugval > 0 {
		println("[+] reply from external agent")
		println(app.req.data)
	}

	_ := json.decode(Message, app.req.data) or {
		return app.json('{"status": "error", "error": "could not parse message request"}')
	}

	
	// forward request to local redis
	redis.lpush("msgbus.system.reply", app.req.data) or {
		return app.json('{"status": "error", "error": "could notsend message to reply"}')
	}

	return app.json('{"status": "accepted"}')
}


['/zbus-cmd'; post]
pub fn (mut app App) zbus_http_cmd() vweb.Result {
	if app.config.debugval > 0 {
		println('[+] request from external agent through zbus-cmd endpoint')
		println(app.req.data)
	}

	mut msg := json.decode(Message, app.req.data) or {
		return app.json('{"status": "error", "error": "could not parse message request"}')
	}
	msg.proxy = true
	msg.retqueue = rand.uuid_v4()
	encoded_msg := json.encode_pretty(msg)
	mut redis := app.config.redis

	// forward request to local redis
	redis.lpush('msgbus.system.remote', encoded_msg) or { panic(err) }

	return app.json('{"retqueue": "$msg.retqueue"}')
}

// TODO: Complete zbus-result endpoint
// ['/zbus-result'; post]
// pub fn (mut app App) zbus_http_result() vweb.Result {
// 	m := json.decode(MessageIdentifer, app.req.data) or { panic ("Failed to parse json with error: $err") }
// 	is_valid_retqueue := is_valid_uuid(m.retqueue) or {panic ("Failed to check valid uuid with error: $err")}
// 	if !is_valid_retqueue {
// 		panic("[-] Invalid Retqueue, it should be a valid UUID")
// 	}
	
// 	return app.json("{success: true}") // FIXME: FOR DEBUG
// }
