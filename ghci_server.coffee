spawn   = require("child_process").spawn
express = require "express"
winston = require "winston"
winston.remove(winston.transports.Console)
winston.add(winston.transports.Console, { "timestamp": true })

EXEC_LIMIT_MS = 500
EXEC_CMD      = "docker"
EXEC_ARGS     = ["run", "-it", '--net="none"', "haskell:latest", "ghci"]
EXCLUDE_REGEX = [/\:\{[\s\S]*\:\}\s*\n/g, /\x1b(\[\?1[lh]|>|=)/g]
INITIAL_CMDS  = [":set +t\n", ":set prompt \"\"\n", ":set prompt2 \"\"\n"]
LOADING_MS    = 5000

class GHCiCore
  initProcess: =>
    winston.info "init process"
    @status   = "load"
    @buf      = ""
    @onFinish = null
    @last_chunk_received = Date.now()

    @ghci_process = spawn EXEC_CMD, EXEC_ARGS
    @ghci_process.stdin.write cmd for cmd in INITIAL_CMDS

    processChunk = (chunk) =>
      @last_chunk_received = Date.now()
      @buf += chunk
      @buf = @buf.replace reg, "" for reg in EXCLUDE_REGEX

    @ghci_process.stdout.on "data", processChunk
    @ghci_process.stderr.on "data", processChunk
    @ghci_process.on "exit", =>
      @onFinish "process killed." if @onFinish
      @initProcess()

  constructor: (@onReady) ->
    @initProcess()

    # check if load/eval finished every 100ms
    setInterval (=>
      if @status is "load" and @buf.length and Date.now() - @last_chunk_received > LOADING_MS
        @buf = ""
        @status = "ready"
        @onReady()
      else if @status is "run" and @buf.length and Date.now() - @last_chunk_received > EXEC_LIMIT_MS
        winston.info "finish: #{@buf}"
        @onFinish @buf
        @onFinish = null
        @status = "ready"
        @onReady()
    ), 100

  eval: (expr, @onFinish) =>
    throw "another one is running" if @status isnt "ready"
    winston.info "eval: #{expr}"
    @buf = ""
    @status = "run"
    @ghci_process.stdin.write ":{\n#{expr}\n:}\n"

class GHCi
  constructor: ->
    @wait_queue = []
    @core = new GHCiCore =>
      @core.eval @wait_queue.shift()... if @wait_queue.length # onReady

  eval: (expr, out) =>
    if @core.status is "ready"
      @core.eval expr, out
    else
      @wait_queue.push [expr, out]

ghci = new GHCi()
app = express()
app.get "/eval", (req, res) ->
  ghci.eval req.query.expr, ((result) -> res.send(result))

app.listen 3000
