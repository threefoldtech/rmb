module grid_db_redis

import server { run_rmb, run_web }
import threefoldtech.vgrid.explorer
import freeflowuniverse.crystallib.redisclient
import freeflowuniverse.crystallib.console

struct TFGRIDDB {
mut:
	explorer  &explorer.ExplorerConnection
	redis     &redisclient.Redis
	tfgridnet string
}

fn new(tfgridnet string) ?&TFGRIDDB {
	mut redis := redisclient.get('localhost:6379')?

	tfgridnet2 := match tfgridnet {
		'main' { explorer.TFGridNet.main }
		'test' { explorer.TFGridNet.test }
		'dev' { explorer.TFGridNet.dev }
		else { explorer.TFGridNet.test }
	}

	mut explorer := explorer.get(tfgridnet2)

	mut srv_config := TFGRIDDB{
		explorer: explorer
		redis: redis
		tfgridnet: tfgridnet
	}
	return &srv_config
}

fn (mut ctx TFGRIDDB) resolver(twinid u32) ?string {
	twin := ctx.explorer.twin_by_id(twinid)?
	return twin.ip
}

// tfgridnet is test,dev or main
pub fn run_server(myid int, tfgridnet string, debug int) ? {
	// start 2 threads to test
	mut logger := console.Logger{}
	rmb_ch := chan IError{}

	go run_web(myid, tfgridnet, logger)
	go run_rmb(myid, tfgridnet, logger, rmb_ch)
}
