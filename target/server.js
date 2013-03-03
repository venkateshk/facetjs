(function() {
  var app, data, druidDriver, druidPass, druidPost, express, http, mysql, respondWithResult, simpleDriver, sqlDriver, sqlPass, sqlRequester;

  express = require('express');

  http = require('http');

  mysql = require('mysql');

  simpleDriver = require('./simpleDriver');

  druidDriver = require('./druidDriver');

  sqlDriver = require('./sqlDriver');

  data = {};

  data.data1 = (function() {
    var i, now, pick, ret, w, _i;
    pick = function(arr) {
      return arr[Math.floor(Math.random() * arr.length)];
    };
    now = Date.now();
    w = 100;
    ret = [];
    for (i = _i = 0; _i < 400; i = ++_i) {
      ret.push({
        id: i,
        time: new Date(now + i * 13 * 1000),
        letter: 'ABC'[Math.floor(3 * i / 400)],
        number: pick([1, 10, 3, 4]),
        scoreA: i * Math.random() * Math.random(),
        scoreB: 10 * Math.random(),
        walk: w += Math.random() - 0.5 + 0.02
      });
    }
    return ret;
  })();

  data.diamonds = require('../data/diamonds.js');

  druidPost = function(_arg) {
    var host, opts, path, port;
    host = _arg.host, port = _arg.port, path = _arg.path;
    opts = {
      host: host,
      port: port,
      path: path,
      method: 'POST',
      headers: {
        'content-type': 'application/json'
      }
    };
    return function(druidQuery, callback) {
      var req;
      druidQuery = new Buffer(JSON.stringify(druidQuery), 'utf-8');
      opts.headers['content-length'] = druidQuery.length;
      req = http.request(opts, function(response) {
        var chunks;
        response.setEncoding('utf8');
        chunks = [];
        response.on('data', function(chunk) {
          chunks.push(chunk);
        });
        response.on('close', function(err) {
          console.log('CLOSE');
        });
        response.on('end', function() {
          chunks = chunks.join('');
          if (response.statusCode !== 200) {
            callback(chunks, null);
            return;
          }
          try {
            chunks = JSON.parse(chunks);
          } catch (e) {
            callback(e, null);
            return;
          }
          callback(null, chunks);
        });
      });
      req.write(druidQuery.toString('utf-8'));
      req.end();
    };
  };

  sqlRequester = function(_arg) {
    var connection, dataset, host, password, user;
    host = _arg.host, user = _arg.user, password = _arg.password, dataset = _arg.dataset;
    connection = mysql.createConnection({
      host: 'localhost',
      user: 'root',
      password: 'root',
      database: 'facet'
    });
    connection.connect();
    return function(sqlQuery, callback) {
      connection.query(sqlQuery, callback);
    };
  };

  app = express();

  app.disable('x-powered-by');

  app.use(express.compress());

  app.use(express.json());

  app.use(express.directory(__dirname + '/../static'));

  app.use(express["static"](__dirname + '/../static'));

  app.use(express["static"](__dirname + '/../target'));

  app.get('/', function(req, res) {
    res.send('Welcome to facet');
  });

  respondWithResult = function(res) {
    return function(err, result) {
      if (err) {
        res.json(500, err);
        return;
      }
      res.json(result);
    };
  };

  app.post('/driver/simple', function(req, res) {
    var context, query, _ref;
    _ref = req.body, context = _ref.context, query = _ref.query;
    simpleDriver(data[context.data])(query, respondWithResult(res));
  });

  sqlPass = sqlRequester({
    host: 'localhost',
    user: 'root',
    password: 'root',
    database: 'facet'
  });

  app.post('/pass/sql', function(req, res) {
    var context, query, _ref;
    _ref = req.body, context = _ref.context, query = _ref.query;
    sqlPass(query, respondWithResult(res));
  });

  app.post('/driver/sql', function(req, res) {
    var context, query, _ref;
    _ref = req.body, context = _ref.context, query = _ref.query;
    sqlDriver({
      requester: sqlPass,
      table: context.table,
      filters: null
    })(query, respondWithResult(res));
  });

  druidPass = druidPost({
    host: '10.60.134.138',
    port: 8080,
    path: '/druid/v2/'
  });

  app.post('/pass/druid', function(req, res) {
    var context, query, _ref;
    _ref = req.body, context = _ref.context, query = _ref.query;
    druidPass(query, respondWithResult(res));
  });

  app.post('/driver/druid', function(req, res) {
    var context, query, _ref;
    _ref = req.body, context = _ref.context, query = _ref.query;
    druidDriver({
      requester: druidPass,
      dataSource: context.dataSource,
      interval: context.interval.map(function(d) {
        return new Date(d);
      }),
      filters: null
    })(query, respondWithResult(res));
  });

  app.listen(9876);

  console.log('Listening on port 9876');

}).call(this);
