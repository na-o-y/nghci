function GHCi() {
  var spawn = require('child_process').spawn,
      ghci  = spawn('ghci'),
      buf   = '';
  
  ghci.stdin.write(':set prompt ""\n');
  ghci.stdin.write(':set +t\n');

  var out = function(data) {
    console.log(data);
  }

  var now = function() { return Date.now(); }
  
  var ltime = now();
  var processBuf = function(buf) {
    buf = buf.replace(/Prelude>\s/g, '');
    buf = buf.replace(/Prelude\|\s/g, '');
    ltime = now();
    return buf;
  }

  setInterval(function() {
    if (buf.length > 0 && now() - ltime > 500) {
      // 入力待ち状態にする
      out(buf);
      buf = '';
    }
  }, 100);
  
  ghci.stdout.on('data', function(data) {
    buf = processBuf(buf+data);
  })

  ghci.stderr.on('data', function(data) {
    buf = processBuf(buf+data);
  })

  return {
    stop: function() { ghci.kill(); },
    exec: function(expr) { ghci.stdin.write(':{\n'+expr+'\n:}\n'); }
  }
}

var http = require('http'),
    url  = require('url');

ghci = GHCi();

http.createServer(function(req, res) {
  if (req.method == 'GET') {
    expr = url.parse(req.url, true).query.expr;
    ghci.exec(expr);
    res.end('{"hoge":"hoge"}');
  }
}).listen(11111)
