/// <reference path="../../typings/mysql/mysql.d.ts" />
"use strict";

import Basics = require("../basics") // Prop up
import Lookup = Basics.Lookup;

import mysql = require("mysql");

import Locator = require("../locatorCommon");
import Requester = require("../requesterCommon");

export interface MySqlRequesterParameters {
  locator: Locator.FacetLocator;
  user: string;
  password: string;
  database: string;
}

export function mySqlRequester(parameters: MySqlRequesterParameters): Requester.FacetRequester<string> {
  var locator = parameters.locator;
  var user = parameters.user;
  var password = parameters.password;
  var database = parameters.database;

  return (request, callback) => {
    var query = request.query;
    locator((err, location) => {
      if (err) {
        callback(err);
        return;
      }

      var connection = mysql.createConnection({
        host: location.host,
        port: location.port || 3306,
        user: user,
        password: password,
        database: database,
        charset: "UTF8_BIN"
      });

      connection.connect();
      connection.query(query, callback);
      connection.end();
    });

  };
}
