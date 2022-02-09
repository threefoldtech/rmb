module server


pub struct Message {
pub mut:
	version int [json: ver]       // protocol version, used for update
	id string [json: uid]         // unique identifier set by server
	command string [json: cmd]    // command to request in dot notation
	expiration int [json: exp]    // expiration in seconds, based on epoch
	retry int [json: try]         // amount of retry if remote is unreachable
	data string [json: dat]       // binary payload to send to remote, base64 encoded
	twin_src int [json: src]      // twinid source, will be set by server
	twin_dst []int [json: dst]    // twinid of destination, can be more than one
	retqueue string [json: ret]   // return queue name where to send reply
	schema string [json: shm]     // schema to define payload, later could enforce payload
	epoch i64 [json: now]         // unix timestamp when request were created
	err string [json: err]        // optional error message if any
}

pub struct HSetEntry {
	key string
mut:
	value Message
}

fn (msg Message) validate() ? {
	if msg.version != 1 {
		return error("protocol version mismatch")
	}

	if msg.command == "" {
		return error("missing command request")
	}

	if msg.twin_dst.len == 0 {
		return error("missing twin destination")
	}

	if msg.retqueue == "" {
		return error("return queue not defined")
	}
}
