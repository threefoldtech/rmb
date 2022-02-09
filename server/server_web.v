module server

import json
import vweb
// import net.http
import despiegk.crystallib.redisclient



fn runweb(config MBusSrv) {
	app := App{
		config: config,
	}

	vweb.run(app, 8051)
}

['/zbus-remote'; post]
pub fn (mut app App) zbus_web_remote() vweb.Result {
	if app.config.debugval > 0 {
		println("[+] request from external agent")
		println(app.req.data)
	}

	_ := json.decode(Message, app.req.data) or {
		return app.json('{"status": "error", "error": "could not parse message request"}')
	}

	// FIXME: could not create redis single time via init_server for some reason
	lock app.config {
		mut redis := redisclient.connect(app.config.raddr) or { panic(err) }

		// forward request to local redis
		redis.lpush("msgbus.system.remote", app.req.data) or { panic(err) }
		redis.socket.close() or { panic(err) }
	}

	return app.json('{"status": "accepted"}')
}

['/zbus-reply'; post]
pub fn (mut app App) zbus_web_reply() vweb.Result {
	if app.config.debugval > 0 {
		println("[+] reply from external agent")
		println(app.req.data)
	}

	_ := json.decode(Message, app.req.data) or {
		return app.json('{"status": "error", "error": "could not parse message request"}')
	}

	lock app.config {
		// FIXME: could not create redis single time via init_server for some reason
		mut redis := redisclient.connect(app.config.raddr) or { panic(err) }

		// forward request to local redis
		redis.lpush("msgbus.system.reply", app.req.data) or { panic(err) }
		redis.socket.close() or { panic(err) }
	}

	return app.json('{"status": "accepted"}')
}

