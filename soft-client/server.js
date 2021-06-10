const StellarSdk = require('stellar-sdk');
const server = new StellarSdk.Server('https://horizon.stellar.org');
const { MessageBusServer } = require('./msgbus')

// test mnemonic
const mnemonic = "industry dismiss casual gym gap music pave gasp sick owner dumb cost"
const Client = require('tfgrid-api-client')
const url = "wss://explorer.devnet.grid.tf/ws"
const DbClient = new Client(url, mnemonic)

async function walletStellarTftHandler(message, payload) {
  if (payload.length != 56)
    return this.error(message, "invalid address format")

  console.log("[+] stellar: query address: " + payload)

  const account = await server.loadAccount(payload)
  
  let total = 0
  const balance = account.balances.map(b => {
    if (b.asset_code == "TFT") {
      total += parseFloat(b.balance)
    }
  })

  return total
}

async function createTwinHandler(message, payload) {
  await DbClient.init()
  console.log(`create twin payload: ${payload}`)
  const block = await DbClient.createTwin(payload)
  return block.toHex()
}

async function getTwinByIDHandler(message, payload) {
  await DbClient.init()
  console.log(`get twin by id payload: ${payload}`)
  const twin = await DbClient.getTwinByID(parseInt(payload))
  return twin
}

const msgBus = new MessageBusServer(6379)
msgBus.withHandler("wallet.stellar.balance.tft", walletStellarTftHandler)
msgBus.withHandler("griddb.twins.create", createTwinHandler)
msgBus.withHandler("griddb.twins.get", getTwinByIDHandler)

msgBus.run()


