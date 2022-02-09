module server

import json
import vweb
// import net.http
// import despiegk.crystallib.redisclient


struct App {
	vweb.Context
mut:
	config MBusSrv
}



fn runweb(myid int, tfgridnet string, debug int)? {

	mut config := srvconfig_get(myid,tfgridnet,debug)?

	app := App{
		config: config,
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

