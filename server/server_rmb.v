module server

import despiegk.crystallib.resp2
import despiegk.crystallib.console { Logger }
import json
import time

// is the main loop getting info from the redis and making sure it gets processed
fn run_rmb(myid int, tfgridnet string, logger Logger, ch chan IError) {
	mut srv := srvconfig_get(myid, tfgridnet, logger) or {
		ch <- error('${@FN} - $err')
		return
	}

	for {
		m := srv.redis.blpop(['msgbus.system.local', 'msgbus.system.remote', 'msgbus.system.reply'],
			'0') or {
			logger.error('error happen with main blpop, $err')
			continue
		}

		key := resp2.get_redis_value(m[0])
		value := resp2.get_redis_value(m[1])

		mut msg := json.decode(Message, value) or {
			logger.error('failed to decode message with error: $err')
			continue
		}

		msg.validate() or { logger.error('Validation failed with error: $err\n$key : $msg') }

		if key == 'msgbus.system.reply' {
			srv.handle_from_reply(mut msg)
		}

		if key == 'msgbus.system.local' {
			srv.handle_from_local(mut msg)
		}

		if key == 'msgbus.system.remote' {
			srv.handle_from_remote(mut msg)
		}
	}
}

fn run_scrubbing(myid int, tfgridnet string, logger Logger) ? {
	mut srv := srvconfig_get(myid, tfgridnet, logger) or {
		logger.error('${@FN} - $err')
		return
	}
	logger.info('handle scrubbing queue every one second')
	for {
		srv.handle_scrubbing() or {
			logger.error('${@FN} - $err')
			continue
		}
		time.sleep(time.second)
	}
}

fn run_retry(myid int, tfgridnet string, logger Logger) ? {
	mut srv := srvconfig_get(myid, tfgridnet, logger) or {
		logger.error('${@FN} - $err')
		return
	}
	logger.info('handle retry queue every one second')
	for {
		srv.handle_retry() or {
			logger.error('${@FN} - $err')
			continue
		}
		time.sleep(time.second)
	}
}
