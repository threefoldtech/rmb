const StellarSdk = require('stellar-sdk');
const server = new StellarSdk.Server('https://horizon.stellar.org');
const msgbus = require('./msgbus')

const Client = require('tfgrid-api-client')
const url = "wss://explorer.devnet.grid.tf/ws"
const mnemonic = "industry dismiss casual gym gap music pave gasp sick owner dumb cost"
const DbClient = new Client(url, mnemonic)

function wallet_stellar_balance_tft(message, payload) {
  if (payload.length != 56)
    return this.error(message, "invalid address format")

  console.log("[+] stellar: query address: " + payload)

  server.loadAccount(payload).then(account => {
    account.balances.forEach(balance => {  
      if (balance.asset_code == "TFT") {
        this.reply(message, balance.balance)
      }
    })
  })
}

async function createTwin(message, payload) {
  await DbClient.init()
  console.log(`create twin payload: ${payload}`)
  const block = await DbClient.createTwin(payload)
  this.reply(message, block.toHex())
}

async function getTwinByID(message, payload) {
  await DbClient.init()
  console.log(`get twin by id payload: ${payload}`)
  const twin = await DbClient.getTwinByID(parseInt(payload))
  this.reply(message, twin)
}

const commands = {
  "wallet.stellar.balance.tft": wallet_stellar_balance_tft,
  "griddb.twins.create": createTwin,
  "griddb.twins.get": getTwinByID,
}

mb = msgbus.server(commands, 6379)
mb.serve()


