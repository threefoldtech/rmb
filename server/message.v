module server

import regex
import time

pub struct Message {
pub mut:
	version    int    [json: ver] // protocol version, used for update
	id         string [json: uid] // unique identifier set by server
	command    string [json: cmd] // command to request in dot notation
	expiration int    [json: exp] // expiration in seconds, based on epoch
	retry      int    [json: try] // amount of retry if remote is unreachable
	data       string [json: dat] // binary payload to send to remote, base64 encoded
	twin_src   int    [json: src] // twinid source, will be set by server
	twin_dst   []int  [json: dst] // twinid of destination, can be more than one
	retqueue   string [json: ret] // return queue name where to send reply
	schema     string [json: shm] // schema to define payload, later could enforce payload
	epoch      i64    [json: now] // unix timestamp when request were created
	proxy      bool   [json: pxy]
	err        string [json: err] // optional error message if any
}

pub struct MessageIdentifier {
mut:
	retqueue string
}

pub struct HSetEntry {
	key string
mut:
	value Message
}

fn is_valid_uuid(uuid string) ?bool {
	query := r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-4[a-fA-F0-9]{3}-[8|9|aA|bB][a-fA-F0-9]{3}-[a-fA-F0-9]{12}$'
	mut re := regex.regex_opt(query) ?
	return re.matches_string(uuid)
}

fn (msg Message) validate_epoch() ? {
	diff := time.now().unix_time() - msg.epoch
	if diff > 60 {
		return error('message is too old, sent since $diff, sent time: $msg.epoch, now: $time.now().unix_time()')
	}
}

fn (msg Message) validate() ? {
	if msg.version != 1 {
		return error('protocol version mismatch')
	}

	if msg.command == '' {
		return error('missing command request')
	}

	if msg.twin_dst.len == 0 {
		return error('missing twin destination')
	}

	if msg.retqueue == '' {
		return error('return queue not defined')
	}
}
