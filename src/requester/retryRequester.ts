/// <reference path="../../typings/backoff/backoff.d.ts" />
"use strict";

import Basics = require("../basics") // Prop up
import Lookup = Basics.Lookup;

import Requester = require("../requesterCommon");

import backoff = require("backoff");

export interface RetryRequesterParameters<T> {
  requester: Requester.FacetRequester<T>;
  retry: number;
  retryOnTimeout: boolean;
}

export function retryRequester<T>(parameters: RetryRequesterParameters<T>) {
  var requester = parameters.requester;
  var retry = parameters.retry;
  var retryOnTimeout = parameters.retryOnTimeout;

  if (typeof retry !== "number") throw new TypeError("retry should be a number");

  return (request: Requester.DatabaseRequest<T>, callback: Requester.DatabaseCallback) => {
    var query = request.query;
    var context = request.context;
    var requestBackoff = backoff.exponential();
    requestBackoff.failAfter(retry);

    requestBackoff.on("ready", (num: number, delay: number) => {
      requester({
        context: context,
        query: query
      }, (err, res) => {
        if (err) {
          if (err.message === "timeout" && !retryOnTimeout) {
            requestBackoff.reset();
            callback(err);
          } else {
            requestBackoff.backoff(err);
          }
          return;
        }

        requestBackoff.reset();
        callback(null, res);
      });
    });

    requestBackoff.on("fail", (err: Error) => {
      callback(err);
    });

    requestBackoff.backoff();
  };
}
