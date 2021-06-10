const redis = require("redis")
const uuid4 = require("uuid4")

//
// client side
//
function prepare(command, destination, expiration, retry) {
  return {
    "ver": 1,
    "uid": "",
    "cmd": command,
    "exp": expiration,
    "dat": "",
    "src": 0,
    "dst": destination,
    "ret": uuid4(),
    "try": retry,
    "shm": "",
    "now": Math.floor(new Date().getTime() / 1000),
    "err": "",
  }
}

function send(message, payload) {
  const data = new Buffer.from(payload)

  message.dat = data.toString('base64')
  const request = JSON.stringify(message)

  this.client.lpush(["msgbus.system.local", request], redis.print)
  console.log(request)
}

function waitfor(message, cb) {
  console.log("waiting reply", message.ret)

  const responses = []
  this.client.blpop(message.ret, 0, function (err, reply) {
    if (err) {
      console.log(`err while waiting for reply: ${err}`)
      return err
    }

    console.log("hello")
    console.log(reply)
    const response = JSON.parse(reply[1])
    // console.log(response)

    response["dat"] = Buffer.from(response["dat"], 'base64').toString('ascii')
    responses.push(response)

    // checking if we have all responses
    if (responses.length == message.dst.length) {
      return cb(responses);
    }

    // wait for remaining responses
    waitfor()
  })
}

function read(message, cb) {
  this._waitfor(message, cb)
}

exports.connect = function (host, port) {
  const root = {
    client: redis.createClient(port),
    request: null,
    responses: null,
    prepare: prepare,
    send: send,
    read: read,
    _waitfor: waitfor,
  }

  root.client.on("error", function (error) {
    console.error(error)
  })

  return root
}


//
// server-side
//
function reply(response, payload) {
  source = response.src

  console.log(response)
  console.log(payload)
  response["dat"] = Buffer.from(JSON.stringify(payload)).toString('base64')
  response["src"] = response["dst"][0]
  response["dst"] = [source]
  response["now"] = Math.floor(new Date().getTime() / 1000)

  replyer = this.client.duplicate({}, function (err, replyer) {
    replyer.lpush(response["ret"], JSON.stringify(response), function (err, r) {
      console.log("[+] response sent to caller")
      console.log(err, r)
    })
  })

}

function error(response, reason) {
  source = response["src"]

  console.log("[-] replying error: " + reason)

  response["dat"] = ""
  response["src"] = response["dst"][0]
  response["dst"] = [source]
  response["now"] = Math.floor(new Date().getTime() / 1000)
  response["err"] = reason

  replyer = this.client.duplicate({}, function (err, replyer) {
    replyer.lpush(reply["ret"], JSON.stringify(response), function (err, r) {
      console.log("[+] error response sent to caller")
      console.log(err, r)
    })
  })

}

function serve() {
  console.log("[+] waiting for request")

  self = this

  cmds = Object.keys(this.commands)
  cmds.push(0)

  this.client.blpop(cmds, function (err, response) {
    if (err) console.log(err)

    channel = response[0]
    request = JSON.parse(response[1])
    payload = Buffer.from(request.dat, 'base64').toString('ascii')

    const handler = {
      client: self.client,
      channel: channel,
      callback: self.commands[channel],
      request: request,
      payload: payload,
      reply: reply,
      error: error,
    };

    console.log("[+] request received: " + handler["channel"])
    handler.callback(request, payload)

    // waiting for next event
    self.serve()
  })

}

exports.server = function (commands, port) {
  cmdnames = Object.keys(commands)
  zcommands = {}

  for (var i in cmdnames) {
    const cmd = cmdnames[i]
    zcommands["msgbus." + cmd] = commands[cmd]
  }

  for (var name in zcommands) {
    console.log("[+] watching: " + name)
  }

  const root = {
    client: redis.createClient(port),
    commands: zcommands,
    serve
  };

  root.client.on("error", function (error) {
    console.error(error);
  })

  return root
}
