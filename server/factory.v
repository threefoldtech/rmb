module server

import threefoldtech.vgrid.explorer
import despiegk.crystallib.redisclient

struct MBusSrv {
mut:
	debugval int // debug level
	myid     int // local twin id
	explorer &explorer.ExplorerConnection
	redis    &redisclient.Redis
}

fn srvconfig_get(myid int, tfgridnet string, debug int) ?&MBusSrv {
	mut redis := redisclient.get_unixsocket_new_default() or {
		return error('failed to connect to redis locally with error: $err')
	}

	tfgridnet2 := match tfgridnet {
		'main' { explorer.TFGridNet.main }
		'test' { explorer.TFGridNet.test }
		'dev' { explorer.TFGridNet.dev }
		else { explorer.TFGridNet.test }
	}

	mut explorer := explorer.get(tfgridnet2)

	mut srv_config := MBusSrv{
		myid: myid
		debugval: debug
		explorer: explorer
		redis: redis
	}
	return &srv_config
}

fn (mut ctx MBusSrv) resolver(twinid u32) ?string {
	twin := ctx.explorer.twin_by_id(twinid) ?
	return twin.ip
}

// tfgridnet is test,dev or main
pub fn run_server(myid int, tfgridnet string, debug int) ? {
	println('[+] twin id: $myid')
	mut server_threads := []thread ?{}
	for _ in 0 .. 1000 {
		server_threads << go run_rmb(myid, tfgridnet, debug)
	}
	println('[+] server: workers started and waiting requests')

	go run_scrubbing(myid, tfgridnet, debug)
	go run_retry(myid, tfgridnet, debug)
	go run_web(myid, tfgridnet, debug)

	for i, th in server_threads {
		th.wait() or { eprintln('thread #$i return with error: $err') }
	}
}
