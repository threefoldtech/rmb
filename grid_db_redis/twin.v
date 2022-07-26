module grid_db_redis

import threefoldtech.vgrid.explorer
import freeflowuniverse.crystallib.redisclient
import json

struct TWIN {
mut:
	id int
	name 		string [skip]
	pub_pgpkey 	string
	pub_sshkey 	string
	//how far is twin away from me, can be used for gossipping protocol
	distance	int
}

fn (mut db TFGRIDDB) key_id(id int) string {
	return "tfgriddb:${db.tfgridnet}:twin:$id"
}

//this is the redis table which is lookup between name & id
fn (mut db TFGRIDDB) key_name_lookup(name string) string {
	return "tfgriddb:${db.tfgridnet}:twin_lookup:$name"
}


pub fn (mut db TFGRIDDB) get_from_id(id int) ? {
	data := db.redis.get(db.key_id(id)) or {
		return error("could not find twin with id: $id")
	}
	twin := json.decode(db.redis.get(db.key_id(id)), TWIN)
	return twin
}

pub fn (mut db TFGRIDDB) get_from_name(name string) ? {
	id := bd.redis.get(db.key_name_lookup(name)) or {
		return error("could not find twin with name: $name")
	}
	twin := db.get_from_id(id) or {
		return error("could not find twin with name: $name.\n$err")
	}
	return twin
}

pub fn (mut db TFGRIDDB) set(twin TWIN) ? {

	if twin.id==0{
		return error("twin id needs to be set")
	}
	if twin.name==0{
		return error("twin name needs to be set")
	}
	if twin.pub_pgpkey==0{
		return error("twin pgpkey needs to be set")
	}

	data := json.encode(twin)

	bd.redis.set(db.key_id(twin.id),data)
	bd.redis.set(db.key_name_lookup(twin.name),twin.id)

	// h.redis.expire(key, h.cache_timeout) or {
	// 	panic('should never get here, if redis worked expire should also work.$err')
	// }	

}
