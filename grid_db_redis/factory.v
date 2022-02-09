module grid_db_redis

import threefoldtech.vgrid.explorer
import despiegk.crystallib.redisclient

struct TFGRIDDB {
mut:
	explorer    		&explorer.ExplorerConnection
	redis				&redisclient.Redis
	tfgridnet			string
}


fn new( tfgridnet string) ?&TFGRIDDB{

	mut redis := redisclient.get_local()?

	tfgridnet2 := match tfgridnet {
		'main'{ explorer.TFGridNet.main }
		'test'{ explorer.TFGridNet.test }
		'dev'{ explorer.TFGridNet.dev }
		else { explorer.TFGridNet.test}
	}

	mut explorer := explorer.get(tfgridnet2)

	mut srv_config := TFGRIDDB{
		explorer: explorer
		redis: redis
		tfgridnet: tfgridnet
	}
	return &srv_config
}

fn (mut ctx TFGRIDDB) resolver(twinid u32) ? string {
	twin := ctx.explorer.twin_by_id(twinid)?
	return twin.ip
}


//tfgridnet is test,dev or main
pub fn run_server(myid int, tfgridnet string, debug int) ? {

	//start 2 threads to test
	go runweb(myid , tfgridnet , debug )
	go run_rmb(myid , tfgridnet , debug )


}
