const StellarSdk = require('stellar-sdk');
const server = new StellarSdk.Server('https://horizon.stellar.org');
const msgbus = require('./msgbus')

function wallet_stellar_balance_tft() {
    if(this.payload.length != 56)
        return this.error("invalid address format")

    console.log("[+] stellar: query address: " + this.payload)

    server.loadAccount(this.payload).then(account => {
        for(var i in account.balances) {
            balance = account.balances[i]

            if(balance.asset_code == "TFT") {
                console.log(this)
                this.reply(balance.balance)
            }
        }
    })
}

var commands = {
    "wallet.stellar.balance.tft": wallet_stellar_balance_tft,
}

mb = msgbus.server(commands, 6372)
mb.serve()


