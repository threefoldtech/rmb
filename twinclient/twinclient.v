module twinclient

import threefoldtech.rmb.client { MessageBusClient, prepare }
import threefoldtech.rmb.server { Message }
import freeflowuniverse.crystallib.redisclient
import encoding.base64

pub struct TwinClient {
pub mut:
	mb        MessageBusClient
	msg_param MsgParameters
}

pub struct MsgParameters {
pub mut:
	destination []int [required]
	expire      int
	retries     int = 2
}

/*
Create a new Client isntance
	Inputs:
		- redis_server (string): Redis server and port number. ex: 'localhost:6379'
		- twin_dist (int): twin id, Client will use it to perform commands. ex: 49
	Output:
		- TwinClient: new TwinClient instance
*/
pub fn new(redis_server string, dest int) ?TwinClient {
	return TwinClient{
		mb: MessageBusClient{
			client: redisclient.get(redis_server)?
		}
		msg_param: MsgParameters{
			destination: [dest]
		}
	}
}

/*
Send a command with payload to a twin server
	Inputs:
		- command (string): represent the function we need to perform on twin server. ex:"twinserver.twins.get"
		- payload (string): represent the arguments/parameters that needed for the command. ex: '{"id": 49}'
		>> The previous example will get twin with id 49
	Output:
		- Message: prepared msg that have been sent
*/
pub fn (mut twin TwinClient) send(command string, payload string) ?Message {
	mut msg := prepare(command, twin.msg_param.destination, twin.msg_param.expire, twin.msg_param.retries)
	twin.mb.send(msg, payload)
	msg.data = base64.encode_str(payload)
	return msg
}

/*
Read the response.
	Inputs:
		- msg: Message we are awaiting a response from it.
	Output:
		- Message: prepared msg that have the response.
*/
pub fn (mut twin TwinClient) read(msg Message) Message {
	return twin.mb.read(msg)[0]
}
