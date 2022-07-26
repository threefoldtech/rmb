module server

import threefoldtech.vgrid.explorer
import freeflowuniverse.crystallib.redisclient
import freeflowuniverse.crystallib.redisclientcore
import freeflowuniverse.crystallib.console { Logger }

struct MBusSrv {
mut:
	myid     int // local twin id
	explorer &explorer.ExplorerConnection
	redis    &redisclient.Redis
	logger   &Logger
}

fn srvconfig_get(myid int, tfgridnet string, logger Logger) ?&MBusSrv {
	mut redis := redisclientcore.get_unixsocket_new() or {
		return error('failed to connect to redis locally with error: $err')
	}

	redis.ping() or { return error('redis server not respond with error: $err') }

	tfgridnet2 := match tfgridnet {
		'main' { explorer.TFGridNet.main }
		'test' { explorer.TFGridNet.test }
		'dev' { explorer.TFGridNet.dev }
		else { explorer.TFGridNet.test }
	}

	mut explorer := explorer.new(tfgridnet2)

	mut srv_config := MBusSrv{
		myid: myid
		logger: &logger
		explorer: explorer
		redis: redis
	}
	return &srv_config
}

fn (mut ctx MBusSrv) resolver(twinid u32) ?string {
	twin := ctx.explorer.twin_by_id(twinid)?
	return twin.ip
}

// tfgridnet is test,dev or main
pub fn run_server(myid int, tfgridnet string, workers int, logger Logger) ? {
	logger.info('twin id: $myid')
	rmb_ch := chan IError{}
	mut server_threads := []thread{}
	logger.info('Starting $workers workers ....')
	for _ in 0 .. workers {
		server_threads << go run_rmb(myid, tfgridnet, logger, rmb_ch)
	}

	go run_scrubbing(myid, tfgridnet, logger)
	go run_retry(myid, tfgridnet, logger)
	go run_web(myid, tfgridnet, logger)

	for _ in 0 .. workers {
		rmb_error := <-rmb_ch
		logger.error('$rmb_error')
	}
}
