module twinclient
import threefoldtech.rmb.client { MessageBusClient }
import threefoldtech.rmb.server { Message }
import despiegk.crystallib.redisclient
import despiegk.crystallib.resp2
import encoding.base64
import rand
import time
import json

pub struct TwinClient{
	MessageBusClient
pub mut:
	msg_param MsgParameters
}

pub struct MsgParameters{
pub mut:
	destination []int [required]
	expire int
	retries int = 2
}

pub fn new(redis_server string, dest int) ?TwinClient {
	/*
		Create a new Client isntance
		Inputs:
			- redis_server (string): Redis server and port number. ex: 'localhost:6379'
			- twin_dist (int): twin id, Client will use it to perform commands. ex: 49
		Output:
			- TwinClient: new TwinClient instance
	*/
	mut dest_arr := [dest]
	return TwinClient{
		client: redisclient.connect(redis_server) ?
		msg_param: MsgParameters{
			destination: dest_arr
		}
	}
}

pub fn (mut twin TwinClient) send (command string, payload string) ?Message {
	/*
		Send a command with payload to a twin server
		Inputs:
			- command (string): represent the function we need to perform on twin server. ex:"twinserver.twins.get"
			- payload (string): represent the arguments/parameters that needed for the command. ex: '{"id": 49}'
			>> The previous example will get twin with id 49
		Output:
			- Message: prepared msg that have been sent
	*/
	msg := Message{
		version: 1
		id: ""
		command: command
		expiration: twin.msg_param.expire
		retry: twin.msg_param.retries
		data: base64.encode_str(payload)
		twin_src: 0
		twin_dst: twin.msg_param.destination
		retqueue: rand.uuid_v4()
		schema: ""
		epoch: time.now().unix_time()
		err: ""
	}
	request := json.encode_pretty(msg)
	twin.client.lpush("msgbus.system.local", request) ?
	return msg
}

pub fn (mut twin TwinClient) read (msg Message) Message {
	/*
		Read the response.
		Inputs:
			- msg: Message we are awaiting a response from it.
		Output:
			- Message: prepared msg that have the response.
	*/
	println('Waiting reply $msg.retqueue')
	results := twin.client.blpop([msg.retqueue], '0') or { panic(err) }
	response_json := resp2.get_redis_value(results[1])
	mut response := json.decode(Message, response_json) or {panic(err)}
	response.data = base64.decode_str(response.data)
	return response
}
