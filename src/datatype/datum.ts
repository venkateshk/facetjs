/// <reference path="../../typings/tsd.d.ts" />
"use strict";

import Basics = require("../basics") // Prop up
import Lookup = Basics.Lookup;

import HigherObjectModule = require("higher-object");
import isInstanceOf = HigherObjectModule.isInstanceOf;
import ImmutableClass = HigherObjectModule.ImmutableClass;
import ImmutableInstance = HigherObjectModule.ImmutableInstance;

import TimeRangeModule = require('./timeRange');
import TimeRange = TimeRangeModule.TimeRange;

export interface DatumJS {
  [name: string]: any;
}

function datumToJS(datum: DatumJS): DatumJS {
  var js: DatumJS = {};
  for (var k in datum) {
    if (!datum.hasOwnProperty(k)) continue;
    var v: any = datum[k];
    if (v == null) {
      v = null;
    } else {
      var typeofV = typeof v;
      if (typeofV === 'object') {
        v = v.toJS(true);
      } else if (typeofV === 'number' && !isFinite(v)) {
        v = { type: 'number', value: String(v) };
      }
    }
    js[k] = v;
  }
  return js;
}

export class Datum implements DatumJS {
  [name: string]: any;

  static fromJS(object: DatumJS, parent: any = null): Datum {
    if (typeof object !== 'object') throw new TypeError("datum must be an object");

    var datum = parent ? Object.create(parent) : new Datum();
    for (var k in object) {
      if (!object.hasOwnProperty(k)) continue;
      var v: any = object[k];
      if (v == null) {
        v = null;
      } else if (Array.isArray(v)) {
        // ToDo: parse it as a dataset
      } else if (typeof v === 'object') {
        switch (v.type) {
          case 'number':
            var infinityMatch = String(v.value).match(/^([-+]?)Infinity$/);
            if (infinityMatch) {
              v = infinityMatch[1] === '-' ? -Infinity : Infinity;
            } else {
              throw new Error("bad number value '" + String(v.value) + "'");
            }
            break;

          case 'timeRange':
            v = TimeRange.fromJS(v);
            break;

          // ToDo: fill this in.

          default:
            throw new Error('can not have an object without a type as a datum value')
        }
      }
      datum[k] = v;
    }

    return datum;
  }

  public toJS(): any {
    return datumToJS(this)
  }

  public toJSON(): any {
    return datumToJS(this)
  }

  public toString(): string {
    return 'Datum'
  }
}