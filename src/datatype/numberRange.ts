/// <reference path="../../typings/tsd.d.ts" />
"use strict";

import Basics = require("../basics") // Prop up
import Lookup = Basics.Lookup;

import HigherObjectModule = require("higher-object");
import isInstanceOf = HigherObjectModule.isInstanceOf;
import ImmutableClass = HigherObjectModule.ImmutableClass;
import ImmutableInstance = HigherObjectModule.ImmutableInstance;

export interface NumberRangeValue {
  start: number;
  end: number;
}

export interface NumberRangeJS {
  start: any;
  end: any;
}

function numberToJS(n: number): any {
  return isFinite(n) ? n : String(n);
}

var check: ImmutableClass<NumberRangeValue, NumberRangeJS>;
export class NumberRange implements ImmutableInstance<NumberRangeValue, NumberRangeJS> {
  static type = 'NUMBER_RANGE';
  static isNumberRange(candidate: any): boolean {
    return isInstanceOf(candidate, NumberRange);
  }

  static fromJS(parameters: NumberRangeJS): NumberRange {
    if (typeof parameters !== "object") {
      throw new Error("unrecognizable numberRange");
    }
    return new NumberRange({
      start: Number(parameters.start),
      end: Number(parameters.end)
    });
  }

  public start: number;
  public end: number;

  constructor(parameters: NumberRangeJS) {
    this.start = parameters.start;
    this.end = parameters.end;
    if (isNaN(this.start)) throw new TypeError('`start` must be a number');
    if (isNaN(this.end)) throw new TypeError('`end` must be a number');
  }

  public valueOf(): NumberRangeValue {
    return {
      start: this.start,
      end: this.end
    };
  }

  public toJS(): NumberRangeJS {
    return {
      start: numberToJS(this.start),
      end: numberToJS(this.end)
    };
  }

  public toJSON(): NumberRangeJS {
    return this.toJS();
  }

  public toString(): string {
    return "[" + this.start + ',' + this.end + ")";
  }

  public equals(other: NumberRange): boolean {
    return NumberRange.isNumberRange(other) &&
      this.start === other.start &&
      this.end === other.end;
  }
}
check = NumberRange;
