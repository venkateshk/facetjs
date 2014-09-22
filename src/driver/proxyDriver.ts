/// <reference path="../../typings/jquery/jquery.d.ts" />
"use strict";

import Basics = require("../basics") // Prop up
import Lookup = Basics.Lookup;

import FacetQueryModule = require("../query/query");
import FacetQuery = FacetQueryModule.FacetQuery;

import SegmentTreeModule = require("../query/segmentTree");
import SegmentTree = SegmentTreeModule.SegmentTree;

import Driver = require("../driverCommon");

export interface AjaxParameters {
  url: string;
  context: Lookup<any>;
  pretty: boolean;
}

export function ajax(parameters: AjaxParameters) {
  var url = parameters.url;
  var posterContext = parameters.context;
  var pretty = parameters.pretty;

  return (request: Driver.Request, callback: Driver.DataCallback) => {
    var query = request.query;
    if (!FacetQuery.isFacetQuery(query)) {
      throw new TypeError("query must be a FacetQuery")
    }

    var context = request.context || {};
    for (var k in posterContext) {
      if (!posterContext.hasOwnProperty(k)) continue;
      context[k] = posterContext[k];
    }

    return jQuery.ajax({
      url: url,
      type: "POST",
      dataType: "json",
      contentType: "application/json",
      data: JSON.stringify({
        context: context,
        query: query.valueOf()
      }, null, pretty ? 2 : null),
      success: (res) => {
        callback(null, new SegmentTree(res));
      },
      error: (xhr) => {
        var err: any;
        var text = xhr.responseText;
        try {
          err = JSON.parse(text)
        } catch (e) {
          err = {
            message: text
          };
        }
        callback(err, null);
      }
    });
  };
}

/*
export function worker(parameters) {
  var url = parameters.url;
  var params = parameters.params;
  var numWorkers = parameters.numWorkers || 1;
  var queue = [];
  var workers = [];

  function onWorkerError(e) {
    console.log("WORKER ERROR: Line " + e.lineno + " in " + e.filename + ": " + e.message);
  }

  function onMessage(e) {
    var type = e.data.type;
    if (type === "ready") {
      this.__ready__ = true;
      tryToProcess();
      return;
    }

    if (!this.__callback__) {
      throw new Error("something went horribly wrong");
    }
    if (type === "error") {
      this.__callback__(e.data.error);
    } else if (type === "result") {
      this.__callback__(null, new SegmentTree(e.data.result));
    } else {
      throw new Error("unexpected message type '" + type + "' from worker");
    }

    this.__callback__ = null;
    tryToProcess();
  }

  while (workers.length < numWorkers) {
    var worker = new Worker(url)
    worker.__ready__ = false;
    worker.__callback__ = null;
    worker.addEventListener("error", onWorkerError, false);
    worker.addEventListener("message", onMessage, false);
    workers.push(worker);
  }

  function sendParams() {
    if (paramError) {
      return;
    }
    workers.forEach((worker) => worker.postMessage({
      type: "params",
      params: paramValues
    }));
  }

  paramError = null;
  paramValues = null;
  if (typeof params === "function") {
    params((err, pv) => {
      paramError = err;
      paramValues = pv;
      sendParams();
    });
  } else {
    paramValues = params;
    sendParams();
  }

  function findAvailableWorker() {
    var _i;
    for (var i = 0; i < workers.length; i++) {
      worker = workers[i];
      if (worker.__ready__ && !worker.__callback__) {
        return worker;
      }
    }
    return null;
  }

  function tryToProcess() {
    var callback, request, _ref, _ref1;
    if (!queue.length) {
      return;
    }
    if (paramError) {
      for (var i = 0; i < queue.length; i++) {
        _ref = queue[_i], request = _ref[0], callback = _ref[1];
        callback(paramError);
      }
      return;
    }
    worker = findAvailableWorker();
    if (!worker) {
      return;
    }

    _ref1 = queue.shift(), request = _ref1[0], callback = _ref1[1];

    worker.__callback__ = callback;
    worker.postMessage({
      type: "request",
      request: {
        context: request.context,
        query: request.query.valueOf()
      }
    });
  }

  return (request, callback) => {
    queue.push([request, callback]);
    tryToProcess();
  };
};

export function verbose(driver) {
  return (query, callback) => {
    console.log("Query:", query);
    return driver(query, (err, res) => {
      console.log("Result:", res);
      return callback(err, res);
    });
  };
}
*/
