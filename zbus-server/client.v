import rand
import time
import json
import encoding.base64
import despiegk.crystallib.redisclient
import despiegk.crystallib.resp2

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

struct MessageBusClient{
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

fn (mut bus MessageBusClient) send(msg Message, payload string) {
	mut update := msg
	update.data = base64.encode_str(payload)
	request := json.encode_pretty(update)
	bus.client.lpush("msgbus.system.local", request) or { panic(err) }
}

fn (mut bus MessageBusClient) read(msg Message) []Message {
	println('Waiting reply $msg.retqueue')
	mut retvalue := resp2.RArray{}
	mut responses := []Message{}
	for responses.len < msg.twin_dst.len {
		results := bus.client.blpop([msg.retqueue], '0') or { panic(err) }
		for value in results{
			retvalue.values << value
		}

		response_json := resp2.get_redis_value_by_index(retvalue, 1)
		mut response_msg := json.decode(Message, response_json) or {panic(err)}
		response_msg.data = base64.decode_str(response_msg.data)
		responses << response_msg
	}
	return responses
}

fn main() {
	mut mb :=  MessageBusClient{
		client: redisclient.connect('localhost:6379') or { panic(err) }
	}
	mut msg_stellar := prepare("wallet.stellar.balance.tft", [12], 0, 2)
	mb.send(msg_stellar,"GA7OPN4A3JNHLPHPEWM4PJDOYYDYNZOM7ES6YL3O7NC3PRY3V3UX6ANM")
	response_stellar := mb.read(msg_stellar)
	println("Result Received for reply: $msg_stellar.retqueue")
	for result in response_stellar {
		println(result)
	}

	mut msg_twin := prepare("griddb.twins.get", [12], 0, 2)
	mb.send(msg_twin,"1")
	response_twin := mb.read(msg_twin)
	println("Result Received for reply: $msg_twin.retqueue")
	for result in response_twin {
		println(result)
	}
	
}
