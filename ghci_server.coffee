spawn   = require("child_process").spawn
express = require "express"
winston = require "winston"
winston.remove(winston.transports.Console)
winston.add(winston.transports.Console, { "timestamp": true })

EXEC_CMD      = "docker"
EXEC_ARGS     = ["run", "-i", '--net="none"', "haskell:latest", "ghci"]
EXCLUDE_REGEX = [/Prelude\|\s/g]
INITIAL_CMDS  = [":set +t\n"]

class GHCiCore
  initProcess: =>
    winston.info "init process"
    @status   = "load"
    @buf      = ""
    @onFinish = null

    @ghci_process = spawn EXEC_CMD, EXEC_ARGS
    @ghci_process.stdin.write cmd for cmd in INITIAL_CMDS

    processChunk = (chunk) =>
      @buf += chunk
      @buf = @buf.replace reg, "" for reg in EXCLUDE_REGEX

    @ghci_process.stdout.on "data", processChunk
    @ghci_process.stderr.on "data", processChunk
    @ghci_process.on "exit", =>
      winston.info "process killed."
      if @status is "run"
        @onFinish "process killed."
        @onFinish = null
      @initProcess()

  constructor: (@onReady) ->
    @initProcess()

    # check if load/eval finished every 100ms
    setInterval (=>
      lines = @buf.split("\n")
      if lines.pop().match /Prelude\>\s$/
        if @status is "load"
          winston.info "process is ready"
        if @status is "run"
          winston.info "eval finish: #{@buf}"
          @onFinish lines.join("\n") if @onFinish
          @onFinish = null
        @buf = ""
        @status = "ready"
        @onReady()
    ), 100

  eval: (expr, @onFinish) =>
    throw "another one is running" if @status isnt "ready"
    winston.info "eval: #{expr}"
    @buf = ""
    @status = "run"
    # workaround
    if expr.match /\:q/g
      @ghci_process.kill("SIGKILL")
      return
    @ghci_process.stdin.write ":{\n#{expr}\n:}\n"

class GHCi
  constructor: ->
    @wait_queue = []
    @core = new GHCiCore =>
      @core.eval @wait_queue.shift()... if @wait_queue.length # onReady

  eval: (expr, out) =>
    winston.info "request: #{expr}"
    if @core.status is "ready"
      @core.eval expr, out
    else
      @wait_queue.push [expr, out]

ghci = new GHCi()
app = express()
app.get "/eval", (req, res) ->
  ghci.eval req.query.expr, ((result) -> res.send(result))

app.listen 3000
