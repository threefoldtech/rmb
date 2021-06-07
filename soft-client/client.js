const msgbus = require("./msgbus");

const mb = msgbus.connect()
mb.prepare("wallet.stellar.balance.tft", [1002], 0)
mb.send("GA7OPN4A3JNHLPHPEWM4PJDOYYDYNZOM7ES6YL3O7NC3PRY3V3UX6ANM")
const values = mb.read()

console.log(values)

mb.prepare("griddb.twins.create", [1002], 0)
mb.send("some_peer_id")
values = mb.read()

console.log(values)

mb.prepare("griddb.twins.get", [1002], 0)
mb.send(1)
values = mb.read()

console.log(values)
