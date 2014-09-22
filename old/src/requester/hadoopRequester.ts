/// <reference path="../../typings/request/request.d.ts" />
"use strict";

var request = require("request");

function postQuery(_arg, callback) {
  var query, timeout, url;
  url = _arg.url;
  query = _arg.query;
  timeout = _arg.timeout;

  request({
    method: "POST",
    url: url + "/job",
    query: query,
    timeout: timeout
  }, (err, response, body) => {
    if (err) {
      callback(err);
      return;
    }

    if (response.statusCode !== 200) {
      callback(new Error("Bad status code"));
      return;
    }

    var job = body.job;
    if (typeof job !== "string") {
      callback(new Error("Bad job ID"));
      return;
    }

    callback(null, job);
  });
}

function checkJobStatus(_arg, callback) {
  var job, timeout, url;
  url = _arg.url;
  job = _arg.job;
  timeout = _arg.timeout;
  request({
    method: "GET",
    url: url + ("/job/" + job),
    json: true,
    timeout: timeout
  }, (err, response, body) => {
    if (err) {
      callback(err);
      return;
    }

    if (response.statusCode !== 200) {
      callback(new Error("Bad status code"));
      return;
    }

    if (typeof body.job === "undefined") {
      callback(null, null);
      return;
    }

    if (typeof body.exceptionMessage === "string") {
      callback(new Error(body.exceptionMessage));
      return;
    }

    if (!Array.isArray(body.results)) {
      callback(new Error("unexpected result"));
    }

    callback(null, body.results);
  });
}

module.exports = (_arg) => {
  var locator, refresh, timeout;
  locator = _arg.locator;
  timeout = _arg.timeout;
  refresh = _arg.refresh;
  refresh || (refresh = 5000);
  timeout || (timeout = 60000);

  return (_arg1, callback) => {
    var context, query, _arg1;
    context = _arg1.context;
    query = _arg1.query;
    locator((err, location) => {
      var url, _ref;
      if (err) {
        callback(err);
        return;
      }

      url = "http://" + location.host + ":" + ((_ref = location.port) != null ? _ref : 8080);

      return postQuery({
        url: url,
        query: query,
        timeout: timeout
      }, (err, job) => {
        var pinger;
        if (err) {
          callback(err);
          return;
        }

        pinger = setInterval((() => {
          checkJobStatus({
            url: url,
            job: job,
            timeout: timeout
          }, (err, results) => {
            if (err) {
              clearInterval(pinger);
              callback(err);
              return;
            }

            if (results) {
              clearInterval(pinger);
              callback(null, results);
            }

          });

        }), refresh);

      });
    });

  };
};
