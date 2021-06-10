const StellarSdk = require('stellar-sdk');
const server = new StellarSdk.Server('https://horizon.stellar.org');
const msgbus = require('./msgbus')

const Client = require('tfgrid-api-client')
const url = "wss://explorer.devnet.grid.tf"
const mnemonic = "some words"
const DbClient = new Client(url, mnemonic)

function wallet_stellar_balance_tft() {
  if (this.payload.length != 56)
    return this.error("invalid address format")

  console.log("[+] stellar: query address: " + this.payload)

  server.loadAccount(this.payload).then(account => {
    account.balances.forEach(balance => {  
      if (balance.asset_code == "TFT") {
        this.reply(balance.balance)
      }
    })
  })
}

async function createTwin() {
  const block = await DbClient.createTwin(this.payload)
  this.reply(block.toHex())
}

async function getTwinByID() {
  const twin = await DbClient.getTwinByID(this.payload)
  this.reply(twin)
}

const commands = {
  "wallet.stellar.balance.tft": wallet_stellar_balance_tft,
  "griddb.twins.create": createTwin,
  "griddb.twins.get": getTwinByID,
}

mb = msgbus.server(commands, 6379)
mb.serve()


