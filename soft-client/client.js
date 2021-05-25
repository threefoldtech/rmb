const msgbus = require("./msgbus");

mb = msgbus.connect()
mb.prepare("wallet.stellar.balance.tft", [1002], 0)
mb.send("GA7OPN4A3JNHLPHPEWM4PJDOYYDYNZOM7ES6YL3O7NC3PRY3V3UX6ANM")
values = mb.read()

console.log(values)


