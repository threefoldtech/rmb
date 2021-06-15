module client

import threefoldtech.rmb.server
import rand
import time
import json
import encoding.base64
import despiegk.crystallib.redisclient
import despiegk.crystallib.resp2

pub struct MessageBusClient{
pub mut:
	client redisclient.Redis
}

pub fn prepare(command string, dst []int, exp int, num_retry int) server.Message {
	msg := server.Message{
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

pub fn (mut bus MessageBusClient) send(msg server.Message, payload string) {
	mut update := msg
	update.data = base64.encode_str(payload)
	request := json.encode_pretty(update)
	bus.client.lpush("msgbus.system.local", request) or { panic(err) }
}

pub fn (mut bus MessageBusClient) read(msg server.Message) []server.Message {
	println('Waiting reply $msg.retqueue')
	mut responses := []server.Message{}
	for responses.len < msg.twin_dst.len {
		results := bus.client.blpop([msg.retqueue], '0') or { panic(err) }
		response_json := resp2.get_redis_value(results[1])
		mut response_msg := json.decode(server.Message, response_json) or {panic(err)}
		response_msg.data = base64.decode_str(response_msg.data)
		responses << response_msg
	}
	return responses
}

// fn main() {
// 	mut mb :=  MessageBusClient{
// 		client: redisclient.connect('localhost:6379') or { panic(err) }
// 	}
// 	mb.client.socket.set_read_timeout(time.Duration(-1))
// 	// println("read timeout $mb.client.socket.read_timeout()")
// 	mut msg_stellar := prepare("wallet.stellar.balance.tft", [12], 0, 2)
// 	mb.send(msg_stellar,"GA7OPN4A3JNHLPHPEWM4PJDOYYDYNZOM7ES6YL3O7NC3PRY3V3UX6ANM")
// 	response_stellar := mb.read(msg_stellar)
// 	println("Result Received for reply: $msg_stellar.retqueue")
// 	for result in response_stellar {
// 		println(result)
// 	}

// 	mut msg_twin := prepare("griddb.twins.get", [12], 0, 2)
// 	mb.send(msg_twin,"1")
// 	response_twin := mb.read(msg_twin)
// 	println("Result Received for reply: $msg_twin.retqueue")
// 	for result in response_twin {
// 		println(result)
// 	}
	
// }
