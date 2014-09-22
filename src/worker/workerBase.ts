"use strict";

import Basics = require("../basics") // Prop up
import Lookup = Basics.Lookup;

import FacetQueryModule = require("../query/query");
import FacetQuery = FacetQueryModule.FacetQuery;

import Driver = require("../driverCommon");

export function workerBase(driverFn: (parameters: any) => Driver.FacetDriver) {
  var driver: Driver.FacetDriver = null;

  function onMessage(e: MessageEvent) {
    var type: string = e.data.type;
    switch (type) {
      case "params":
        driver = driverFn(e.data.params);
        postMessage({
          type: "ready"
        }, null);
        break;

      case "request":
        if (!driver) {
          throw new Error("request received before params");
        }

        var request: any = e.data.request;
        var context: Lookup<any> = request.context;
        var queryJS: any[] = request.query;
        try {
          var query = new FacetQuery(queryJS);
        } catch (error) {
          postMessage({
            type: "error",
            error: {
              message: error.message
            }
          }, null);
          return;
        }

        driver({
          context: context,
          query: query
        }, (err, res) => {
          if (err) {
            postMessage({
              type: "error",
              error: err
            }, null);
          } else {
            postMessage({
              type: "result",
              result: res
            }, null);
          }
        });
        break;

      default:
        throw new Error("unexpected message type '" + type + "' from manager");
    }

  }

  return self.addEventListener("message", onMessage, false);
}
