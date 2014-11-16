spawn = require("child_process").spawn
express = require "express"

EXEC_LIMIT_MS = 500
EXEC_CMD      = "docker"
EXEC_ARGS     = ["run", "-it", '--net="none"', "haskell:latest", "ghci"]
SKIP_LINES    = 4 # ignoring beginning lines of ghci
EXCLUDE_REGEX = [/Prelude(>|\|)\s/g, /\:\{[\s\S]*\:\}\s*\n/g]
INITIAL_CMDS  = [":set +t\n"]

class GHCiCore
  initProcess: =>
    @status   = "ready"
    @buf      = ""
    @onFinish = null
    @last_chunk_received = Date.now()

    @ghci_process = spawn EXEC_CMD, EXEC_ARGS
    @ghci_process.stdin.write cmd for cmd in INITIAL_CMDS

    skip_lines = SKIP_LINES
    processChunk = (chunk) =>
      chunk = chunk.toString()
      while (skip_lines and (pos = chunk.indexOf("\n")) != -1)
        skip_lines -= 1
        chunk = chunk.slice(pos+1)
      if skip_lines == 0 and chunk != ""
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

    # check if eval finished every 100ms
    setInterval (=>
      if @status is "run" and @buf.length and Date.now() - @last_chunk_received > EXEC_LIMIT_MS
        @onFinish @buf
        @onFinish = null
        @status = "ready"
        @onReady()
    ), 100

  eval: (expr, @onFinish) =>
    throw "another one is running" if @status isnt "ready"
    @buf = ""
    @status = "run"
    @ghci_process.stdin.write ":{\n#{expr}\n:}\n"

class GHCi
  constructor: ->
    @core = new GHCiCore =>
      @core.eval @wait_queue.shift()... if @wait_queue.length # onReady
    @wait_queue = []

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
