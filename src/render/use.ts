"use strict";

import Basics = require("../basics") // Prop up
import Lookup = Basics.Lookup;

module.exports = {
  literal: useLiteral,
  prop: (propName) => {
    if (!propName) {
      throw new Error("must specify prop name");
    }
    if (typeof propName !== "string") {
      throw new TypeError("prop name must be a string");
    }
    return (segment) => segment.getProp(propName);
  },
  scale: (scaleName, use) => {
    use = wrapLiteral(use);
    if (!scaleName) {
      throw new Error("must specify scale name");
    }
    if (typeof scaleName !== "string") {
      throw new TypeError("scale name must be a string");
    }
    return (segment) => {
      var scale;
      scale = segment.getScale(scaleName);
      if (scale.train) {
        throw new Error("'" + scaleName + "' scale is untrained");
      }
      use || (use = scale.use);
      return scale.fn(use(segment));
    };
  },
  space: (attrName, scale) => {
    if (typeof attrName !== "string") {
      throw new Error("must specify attr");
    }
    if (scale == null) {
      scale = 1;
    }
    return (space) => space.attr[attrName] * scale;
  },
  interval: (start, end) => {
    start = wrapLiteral(start);
    end = wrapLiteral(end);
    return (segment) => new Interval(start(segment), end(segment));
  },
  length: (interval) => {
    interval = wrapLiteral(interval);
    return (segment) => {
      var i;
      i = interval(segment);
      if (!isInstanceOf(i, Interval)) {
        throw new TypeError("must have an interval");
      }
      return i.valueOf();
    };
  },
  fn: (...args, fn) => function (segment) {
    if (typeof fn !== "function") {
      throw new TypeError("second argument must be a function");
    }
    return fn.apply(this, args.map((arg) => arg(segment)));
  }
};
