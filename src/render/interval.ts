"use strict";

var isInstanceOf;

isInstanceOf = require("../utils").isInstanceOf;

class Interval {
  constructor(public start, public end) {
    if (typeof this.start.valueOf() !== "number") {
      throw new Error("invalid start (is '" + this.start + "')");
    }
    if (typeof this.end.valueOf() !== "number") {
      throw new Error("invalid end (is '" + this.end + "')");
    }
    return;
  }

  public valueOf() {
    return this.end - this.start;
  }

  public toString() {
    if (isInstanceOf(this.start, Date)) {
      return "[" + (this.start.toISOString()) + ", " + (this.end.toISOString()) + ")";
    } else {
      return "[" + (this.start.toPrecision(3)) + ", " + (this.end.toPrecision(3)) + ")";
    }
  }
}

Interval.fromArray = (arr) => {
  var end, endDate, endType, start, startDate, startType;
  if (arr.length !== 2) {
    throw new Error("Interval must have length of 2 (is: " + arr.length + ")");
  }
  start = arr[0], end = arr[1];
  startType = typeof start;
  endType = typeof end;
  if (startType === "string" && endType === "string") {
    startDate = new Date(start);
    if (isNaN(startDate.valueOf())) {
      throw new Error("bad start date '" + start + "'");
    }
    endDate = new Date(end);
    if (isNaN(endDate.valueOf())) {
      throw new Error("bad end date '" + end + "'");
    }
    return new Interval(startDate, endDate);
  }

  return new Interval(start, end);
};

module.exports = Interval;
