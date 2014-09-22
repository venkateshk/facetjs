/// <reference path="../../typings/jquery/jquery.d.ts" />
"use strict";

import Basics = require("../basics") // Prop up
import Lookup = Basics.Lookup;

import Requester = require("../requesterCommon");

export interface AjaxParameters {
  url: string;
  context: Lookup<any>;
  pretty: boolean;
}

export function ajax<T>(parameters: AjaxParameters) {
  var url = parameters.url;
  var posterContext = parameters.context;
  var pretty = parameters.pretty;

  return (request: Requester.DatabaseRequest<T>, callback: Requester.DatabaseCallback) => {
    var context = request.context || {};
    var query = request.query;

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
        callback(null, res);
      },
      error: (xhr) => {
        var err: any;
        var text = xhr.responseText;
        try {
          err = JSON.parse(text);
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
