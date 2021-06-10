import rand
import time
import json
import encoding.base64
import despiegk.crystallib.redisclient

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
	epoch int [json: now]         // unix timestamp when request were created
	err string [json: err]        // optional error message if any
}

struct MessageBus{
mut:
	client redisclient.Redis
}

fn prepare(command string, dst []int, exp int, num_retry int) Message {
	msg := Message{
		version: 1
		id: ""
		command: command
		expiration: exp
		retry: num_retry
		data: ""
		twin_src: 0
		twin_dst: dst
		retqueue: rand.uuid_v4()
		schema: ""
		epoch: time.now().unix_time()
		err: ""
	}
	return msg
}

fn (mut bus MessageBus) send(mut msg Message, payload string) {
	msg.data = base64.encode_str(payload)
	request := json.encode_pretty(msg)
	bus.client.lpush("msgbus.system.local", request) or { panic(err) }
}

// fn (mut bus MessageBus) read(mut msg Message, payload string) {
// 	msg.data = base64.encode_str(payload)
// 	bus.client.lpush("msgbus.system.local", request)
// }

// fn main() {
// 	mut mb :=  MessageBus{
// 		client: redisclient.connect('localhost:6379') or { panic(err) }
// 	}
// 	mut msg := prepare("wallet.stellar.balance.tft", [12], 0, 2)
// 	mb.send(mut msg,"GA7OPN4A3JNHLPHPEWM4PJDOYYDYNZOM7ES6YL3O7NC3PRY3V3UX6ANM")

// }
