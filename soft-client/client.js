const { MessageBusClient } = require('./msgbus')

const mb = new MessageBusClient(6379)

const message = mb.prepare("wallet.stellar.balance.tft", [14], 0, 2)
const parsedAddress = Buffer.from("GA7OPN4A3JNHLPHPEWM4PJDOYYDYNZOM7ES6YL3O7NC3PRY3V3UX6ANM").toString('base64')
mb.send(message, parsedAddress)
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


// const message = mb.prepare("zos.statistics.get", [13], 0, 2)
// mb.send(message, "")
// mb.read(message, function (result) {
//   console.log("result received")
//   console.log(result)
// })

// base 64 encoded volume workload
// const wl = 'eyJ2ZXJzaW9uIjoxMSwidHdpbl9pZCI6MTQsImRlcGxveW1lbnRfaWQiOjAsIm1ldGFkYXRhIjoiIiwiZGVzY3JpcHRpb24iOiIiLCJleHBpcmF0aW9uIjowLCJzaWduYXR1cmVfcmVxdWlyZW1lbnQiOnsicmVxdWVzdHMiOlt7InR3aW5faWQiOjE0LCJyZXF1aXJlZCI6ZmFsc2UsIndlaWdodCI6MX1dLCJ3ZWlnaHRfcmVxdWlyZWQiOjEsInNpZ25hdHVyZXMiOlt7InR3aW5faWQiOjE0LCJzaWduYXR1cmUiOiIwYWE0Y2FmNjVhNGEyNTIwNjM1NGFkNzE4MjJiZGRiMDkyYmRjMTY5NDIyZWQ3NjM4ZTRhMDkyOTk0YzUyMTdjOTU1OGJiN2FhMzZiMjQzNGM5ZTQ3NGYxZTAzNDk2YWEzYzNmODFhNmViMmUwYTJjZDQzYzM4ZDNlNGViYTIwNCJ9XX0sIndvcmtsb2FkcyI6W3sidmVyc2lvbiI6MCwibmFtZSI6InZvbHVtZSIsInR5cGUiOiJ2b2x1bWUiLCJkYXRhIjp7InNpemUiOjEwNzM3NDE4MjQwLCJ0eXBlIjoic3NkIn0sImNyZWF0ZWQiOjAsIm1ldGFkYXRhIjoiIiwiZGVzY3JpcHRpb24iOiJ2b2x1bWUgMiIsInJlc3VsdCI6eyJjcmVhdGVkIjowLCJzdGF0ZSI6IiIsIm1lc3NhZ2UiOiIiLCJkYXRhIjpudWxsfX1dfQ'

// const message = mb.prepare("zos.deployment.deploy", [13], 0, 2)
// mb.send(message, wl)
// mb.read(message, function (result) {
//   console.log("result received")
//   console.log(result)
// })

// const getRequest = {
//   twinID: 14,
//   deploymentID: 0
// }

// const x = Buffer.from(JSON.stringify(getRequest)).toString('base64')

// const message = mb.prepare("zos.deployment.get", [13], 0, 2)
// mb.send(message, x)
// mb.read(message, function (result) {
//   console.log("result received")
//   console.log(result)
// })

// const message = mb.prepare("zos.deployment.delete", [13], 0, 2)
// mb.send(message, x)
// mb.read(message, function (result) {
//   console.log("result received")
//   console.log(result)
// })
