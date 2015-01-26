/// <reference path="../../typings/tsd.d.ts" />
"use strict";

import Basics = require("../basics") // Prop up
import Lookup = Basics.Lookup;
import dummyObject = Basics.dummyObject;
import Dummy = Basics.Dummy;

import HigherObjectModule = require("higher-object");
import isInstanceOf = HigherObjectModule.isInstanceOf;
import ImmutableClass = HigherObjectModule.ImmutableClass;
import ImmutableInstance = HigherObjectModule.ImmutableInstance;

export interface TimeRangeJS {
  type?: string;
  start?: any;
  end?: any
}

var check: ImmutableClass<TimeRangeJS, TimeRangeJS>;
export class TimeRange implements ImmutableInstance<TimeRangeJS, TimeRangeJS> {
  static classMap: any = {};
  static fromJS(parameters: TimeRangeJS): TimeRange {
    if (typeof parameters !== "object") {
      throw new Error("unrecognizable shape");
    }
    if (!parameters.hasOwnProperty("shape")) {
      throw new Error("shape must be defined");
    }
    if (typeof parameters.shape !== "string") {
      throw new Error("shape must be a string");
    }
    var ClassFn = TimeRange.classMap[parameters.shape];
    if (!ClassFn) {
      throw new Error("unsupported shape '" + parameters.shape + "'");
    }
    return ClassFn.fromJS(parameters);
  }

  static isTimeRange(candidate: any): boolean {
    return isInstanceOf(candidate, TimeRange);
  }

  public shape: string;
  public x: number;
  public y: number;

  constructor(parameters: TimeRangeJS, dummy: Dummy = null) {
    if (dummy !== dummyObject) {
      throw new TypeError("can not call `new TimeRange` directly use TimeRange.fromJS instead");
    }
    this.x = parameters.x;
    this.y = parameters.y;
  }

  public _ensureTimeRange(shape: string): void {
    if (!this.shape) {
      this.shape = shape;
      return;
    }
    if (this.shape !== shape) {
      throw new TypeError("incorrect shape '" + this.shape + "' (needs to be: '" + shape + "')");
    }
  }

  public valueOf(): TimeRangeJS {
    return {
      shape: this.shape,
      x: this.x,
      y: this.y
    };
  }

  public toJS(): TimeRangeJS {
    return this.valueOf();
  }

  public toJSON(): TimeRangeJS {
    return this.valueOf();
  }

  public toString(): string {
    return "TimeRange(" + this.x + ',' + this.y + ")";
  }

  public equals(other: TimeRange): boolean {
    return TimeRange.isTimeRange(other) &&
      this.shape === other.shape &&
      this.x === other.x &&
      this.y === other.y;
  }
}
check = TimeRange;
