# NodeGHCi

NodeGHCi is a GHCi (Haskell REPL) API server on Node.js.

Backend processes of GHCi run on secure Docker container.

# Installation

Please make sure that Docker and appropriate Docker image (haskell:latest) are installed.

```
$ npm install
$ npm install -g coffee-script
$ coffee ghci_server.coffee
```

# API

```
GET /eval?expr=[PARAM]
```
