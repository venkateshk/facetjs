/// <reference path="../../typings/tsd.d.ts" />
"use strict";

import Basics = require("../basics") // Prop up
import Lookup = Basics.Lookup;

import HigherObjectModule = require("higher-object");
import isInstanceOf = HigherObjectModule.isInstanceOf;
import ImmutableClass = HigherObjectModule.ImmutableClass;
import ImmutableInstance = HigherObjectModule.ImmutableInstance;

export interface TimeRangeValue {
  type?: string;
  start?: Date;
  end?: Date;
}

export interface TimeRangeJS {
  type?: string;
  start?: any;
  end?: any;
}

function getDate(date: any, name: string): Date {
  if (!date) throw new TypeError('timeRange must have a `' + name + '`');
  if (typeof date === 'string') date = new Date(date);
  if (!date.getDay) throw new TypeError('timeRange must have a `' + name + '` that is a Date');
  return date;
}

var check: ImmutableClass<TimeRangeValue, TimeRangeJS>;
export class TimeRange implements ImmutableInstance<TimeRangeValue, TimeRangeJS> {
  static isTimeRange(candidate: any): boolean {
    return isInstanceOf(candidate, TimeRange);
  }

  static fromJS(parameters: TimeRangeJS): TimeRange {
    if (typeof parameters !== "object") {
      throw new Error("unrecognizable timeRange");
    }
    return new TimeRange({
      start: getDate(parameters.start, 'start'),
      end: getDate(parameters.end, 'end')
    });
  }

  public start: Date;
  public end: Date;

  constructor(parameters: TimeRangeJS) {
    this.start = parameters.start;
    this.end = parameters.end;
  }

  public valueOf(): TimeRangeValue {
    return {
      start: this.start,
      end: this.end
    };
  }

  public toJS(): TimeRangeJS {
    return this.valueOf();
  }

  public toJSON(): TimeRangeJS {
    return this.valueOf();
  }

  public toString(): string {
    return "[" + this.start.toISOString() + ',' + this.end.toISOString() + ")";
  }

  public equals(other: TimeRange): boolean {
    return TimeRange.isTimeRange(other) &&
      this.start.valueOf() === other.start.valueOf() &&
      this.end.valueOf() === other.end.valueOf();
  }
}
check = TimeRange;
