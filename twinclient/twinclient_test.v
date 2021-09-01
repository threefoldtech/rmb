import threefoldtech.rmb.twinclient

fn test_twin_client() {
	mut twin :=  client.new('localhost:6379', 49) or {panic("Can't connect to redis server with error $err")}

	mut msg := twin.send("twinserver.twins.get", '{"id": 49}') or {panic("Can't send msg with error $err")}
	response := twin.read(msg)
	println("Result Received for reply: $msg.retqueue")
	println(response)
}