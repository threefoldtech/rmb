const { MessageBusClient } = require('./msgbus')

const mb = new MessageBusClient(6379)

const message = mb.prepare("wallet.stellar.balance.tft", [12], 0, 2)
mb.send(message, "GA7OPN4A3JNHLPHPEWM4PJDOYYDYNZOM7ES6YL3O7NC3PRY3V3UX6ANM")
mb.read(message, function (result) {
  console.log("result received")
  console.log(result)
})

// mb.prepare("griddb.twins.create", [1002], 0)
// mb.send("some_peer_id")
// values = mb.read()

// console.log(values)

const twinsget = mb.prepare("griddb.twins.get", [12], 0)
mb.send(twinsget, "1")
mb.read(twinsget, function (result) {
  console.log("result received")
  console.log(result)

  console.log("closing")
  process.exit(0)
})
