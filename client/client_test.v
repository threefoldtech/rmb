import threefoldtech.rmb.client
import despiegk.crystallib.redisclient

fn test_client() {
	mut mb :=  client.MessageBusClient{
		client: redisclient.connect('localhost:6379') or { panic(err) }
	}
	
	mut msg_stellar := client.prepare("wallet.stellar.balance.tft", [12], 0, 2)
	mb.send(msg_stellar,"GA7OPN4A3JNHLPHPEWM4PJDOYYDYNZOM7ES6YL3O7NC3PRY3V3UX6ANM")
	response_stellar := mb.read(msg_stellar)
	println("Result Received for reply: $msg_stellar.retqueue")
	for result in response_stellar {
		println(result)
	}

	mut msg_twin := client.prepare("griddb.twins.get", [12], 0, 2)
	mb.send(msg_twin,"1")
	response_twin := mb.read(msg_twin)
	println("Result Received for reply: $msg_twin.retqueue")
	for result in response_twin {
		println(result)
	}
	
}