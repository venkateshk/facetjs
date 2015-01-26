/// <reference path="../../typings/tsd.d.ts" />
"use strict";

import Basics = require("../basics") // Prop up
import Lookup = Basics.Lookup;

import HigherObjectModule = require("higher-object");
import isInstanceOf = HigherObjectModule.isInstanceOf;
import ImmutableClass = HigherObjectModule.ImmutableClass;
import ImmutableInstance = HigherObjectModule.ImmutableInstance;

export interface Stat {
  [name: string]: any;
}

function statToJS(stat: Stat): Stat {
  var js: Stat = {};
  for (var k in stat) {
    if (!stat.hasOwnProperty(k)) continue;
    var v: any = stat[k];
    js[k] = Array.isArray(v) ? v.map(statToJS) : (typeof v.toJS === 'function' ? v.toJS() : v);
  }
  return js;
}

export class StatBase implements Stat {
  [name: string]: any;

  // Future static fromJS
  //protoLink = (object, parent = null) ->
  //  return object unless typeof object is 'object'
  //  if Array.isArray(object)
  //    return object.map((o) -> protoLink(o, parent))
  //  newObject = new Object(parent)
  //  for own k, v of object
  //    console.log("k", k);
  //    newObject[k] = protoLink(v, newObject)
  //  return newObject


  public toJS(): any {
    return statToJS(this)
  }

  public toString(): string {
    return 'Stat'
  }
}