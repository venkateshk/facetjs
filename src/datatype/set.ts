/// <reference path="../../typings/tsd.d.ts" />
"use strict";

import Basics = require("../basics") // Prop up
import Lookup = Basics.Lookup;

import HigherObjectModule = require("higher-object");
import isInstanceOf = HigherObjectModule.isInstanceOf;
import ImmutableClass = HigherObjectModule.ImmutableClass;
import ImmutableInstance = HigherObjectModule.ImmutableInstance;

export interface SetValue {
  values: { [k: string]: boolean }
}

export interface SetJS {
  values: Array<any>
}

function arrayToHash(a: Array<string>): { [k: string]: boolean } {
  var ret: { [k: string]: boolean } = {};
  for (var i = 0; i < a.length; i++) {
    ret[String(a[i])] = true;
  }
  return ret;
}

function hashToArray(a: { [k: string]: boolean }): Array<string> {
  var ret: Array<string> = [];
  for (var k in a) {
    if (a[k]) ret.push(k);
  }
  return ret.sort();
}

var check: ImmutableClass<SetValue, SetJS>;
export class Set implements ImmutableInstance<SetValue, SetJS> {
  static type = 'SET';
  static isSet(candidate: any): boolean {
    return isInstanceOf(candidate, Set);
  }

  static fromJS(parameters: SetJS): Set {
    if (typeof parameters !== "object") {
      throw new Error("unrecognizable set");
    }
    return new Set({
      values: arrayToHash(parameters.values)
    });
  }

  private values: Lookup<boolean>;

  constructor(parameters: SetValue) {
    this.values = parameters.values;
  }

  public valueOf(): SetValue {
    return {
      values: this.values
    };
  }

  public toJS(): SetJS {
    return {
      values: hashToArray(this.values)
    };
  }

  public toJSON(): SetJS {
    return this.toJS();
  }

  public toString(): string {
    return this.values.toString();
  }

  public equals(other: Set): boolean {
    if (!Set.isSet(other)) return false;
    var thisValues = this.toJS().values;
    var otherValues = other.toJS().values;
    return otherValues.every((value, index) => value === thisValues[index]);
  }

  public union(other: Set): Set {
    var ret: { [k: string]: boolean } = {};
    for (var k in this.valueOf().values) ret[k] = true;
    for (var k in other.valueOf().values) ret[k] = true;
    return new Set({values: ret});
  }

  public intersect(other: Set): Set {
    var ret: { [k: string]: boolean } = {};
    var othersValues = other.valueOf().values;
    for (var k in this.valueOf().values) {
      if (othersValues[k]) {
        ret[k] = true;
      }
    }
    return new Set({values: ret});
  }
}
check = Set;
