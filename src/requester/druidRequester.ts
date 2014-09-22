/// <reference path="../../typings/request/request.d.ts" />
/// <reference path="../../definitions/druid.d.ts" />
"use strict";

import Basics = require("../basics") // Prop up
import Lookup = Basics.Lookup;

import request = require('request');

import Locator = require("../locatorCommon");
import Requester = require("../requesterCommon");

export interface DruidRequesterParameters {
  locator: Locator.FacetLocator;
  timeout: number;
}

export function druidRequester(parameters: DruidRequesterParameters): Requester.FacetRequester<Druid.Query> {
  var locator = parameters.locator;
  var timeout = parameters.timeout;

  return (req, callback) => {
    var context = req.context || {};
    var query = req.query;
    if (Array.isArray(query.intervals) && query.intervals.length === 1 && query.intervals[0] === "1000-01-01/1000-01-02") {
      callback(null, []);
      return;
    }

    locator((err, location) => {
      if (err) {
        callback(err);
        return;
      }

      if (timeout != null) {
        query.context || (query.context = {});
        query.context.timeout = timeout;
      }

      var url = "http://" + location.host + ":" + (location.port || 8080) + "/druid/v2/";
      var param: request.Options;
      if (query.queryType === "introspect") {
        var dataSourceString = query.dataSource.type === "union" ? query.dataSource.dataSources[0] : query.dataSource;
        param = {
          method: "GET",
          url: url + ("datasources/" + dataSourceString),
          json: true,
          timeout: timeout
        }
      } else {
        param = {
          method: "POST",
          url: url + (context['pretty'] ? "?pretty" : ""),
          json: query,
          timeout: timeout
        };
      }

      return request(param, (err, response, body) => {
        if (err) {
          if (err.message === "ETIMEDOUT") {
            err = new Error("timeout");
          }
          err.query = query;
          callback(err);
          return;
        }

        if (response.statusCode !== 200) {
          if ((body != null ? body.error : void 0) === "Query timeout") {
            err = new Error("timeout");
          } else {
            err = new Error("Bad status code");
            err.query = query;
          }
          callback(err);
          return;
        }
        if (query.queryType === "introspect" && (body.dimensions != null ? body.dimensions.length : void 0) === 0 && (body.metrics != null ? body.metrics.length : void 0) === 0) {
          err = new Error("No such datasource");
          err.dataSource = query.dataSource;
          callback(err);
          return;
        }

        if (Array.isArray(body) && !body.length) {
          request({
            method: "GET",
            url: url + "datasources",
            json: true,
            timeout: timeout
          }, (err, response, body) => {
            if (err) {
              err.dataSource = query.dataSource;
              callback(err);
              return;
            }

            if (response.statusCode !== 200 || !Array.isArray(body)) {
              err = new Error("Bad response");
              err.dataSource = query.dataSource;
              callback(err);
              return;
            }

            var queryDataSources: string[] = query.dataSource.type === "union" ?
                                               query.dataSource.dataSources :
                                               [query.dataSource];
            if (queryDataSources.every((dataSource) => body.indexOf(dataSource) < 0)) {
              err = new Error("No such datasource");
              err.dataSource = query.dataSource;
              callback(err);
              return;
            }

            callback(null, []);
          });
          return;
        }

        callback(null, body);
      });
    });

  };
}
