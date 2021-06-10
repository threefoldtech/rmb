const msgbus = require("./msgbus");

const mb = msgbus.connect()
const message = mb.prepare("msgbus.wallet.stellar.balance.tft", [4], 0, 2)
mb.send(message, "GA7OPN4A3JNHLPHPEWM4PJDOYYDYNZOM7ES6YL3O7NC3PRY3V3UX6ANM")
mb.read(message, function (result) {
  console.log("result received")
  console.log(result)

  console.log("closing")
  process.exit(0)
})



// mb.prepare("griddb.twins.create", [1002], 0)
// mb.send("some_peer_id")
// values = mb.read()

// console.log(values)

// const message = mb.prepare("griddb.twins.get", [1002], 0)
// mb.send(message, "1")
// mb.read(message)

// console.log(`values: ${values}`)
