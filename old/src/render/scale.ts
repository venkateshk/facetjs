/// <reference path="../../typings/tsd.d.ts" />
"use strict";

import Basics = require("../basics") // Prop up
import Lookup = Basics.Lookup;

import d3 = require("d3");

import HigherObjectModule = require("higher-object");
import isInstanceOf = HigherObjectModule.isInstanceOf;
import ImmutableClass = HigherObjectModule.ImmutableClass;
import ImmutableInstance = HigherObjectModule.ImmutableInstance;

export class Scale {
  public scaleFn: any;

  static isScale(candidate: any): boolean {
    return isInstanceOf(candidate, Scale);
  }

  constructor() {

  }
}

/*
function scaleOverInterval(baseScale) {
  return (x) => {
    if (isInstanceOf(x, Interval)) {
      return new Interval(baseScale(x.start), baseScale(x.end));
    } else {
      return baseScale(x);
    }
  };
}

function min(a, b) {
  if (a < b) {
    return a;
  } else {
    return b;
  }
}
function max(a, b) {
  if (a < b) {
    return b;
  } else {
    return a;
  }
}

module.exports = {
  linear: (_arg: any = {}) => {
    var nice, time, _arg, _ref;
    _ref = _arg != null ? _arg : {}, nice = _ref.nice, time = _ref.time;
    return () => {
      var baseScale, self;
      baseScale = time ? d3.time.scale() : d3.scale.linear();

      self = {
        domain: (segments, domain) => {
          var domainMax, domainMin, domainValue;
          domain = wrapLiteral(domain);

          domainMin = Infinity;
          domainMax = -Infinity;

          segments.forEach((segment) => {
            domainValue = domain(segment);
            if (isInstanceOf(domainValue, Interval)) {
              domainMin = min(domainMin, min(domainValue.start, domainValue.end));
              return domainMax = max(domainMax, max(domainValue.start, domainValue.end));
            } else {
              domainMin = min(domainMin, domainValue);
              return domainMax = max(domainMax, domainValue);
            }
          });

          if (!(isFinite(domainMin) && isFinite(domainMax))) {
            throw new Error("Domain went into infinites");
          }
          baseScale.domain([domainMin, domainMax]);

          if (nice) {
            baseScale.nice();
          }

          delete self.domain;
          self.base = baseScale;
          self.use = domain;
          self.fn = scaleOverInterval(baseScale);
        },
        range: (spaces, range) => {
          var rangeFrom, rangeTo, rangeValue;
          range = wrapLiteral(range);

          rangeFrom = -Infinity;
          rangeTo = Infinity;

          spaces.forEach((space) => {
            rangeValue = range(space);
            if (isInstanceOf(rangeValue, Interval)) {
              rangeFrom = rangeValue.start;
              return rangeTo = min(rangeTo, rangeValue.end);
            } else {
              rangeFrom = 0;
              return rangeTo = min(rangeTo, rangeValue);
            }
          });

          if (!(isFinite(rangeFrom) && isFinite(rangeTo))) {
            throw new Error("Range went into infinites");
          }
          baseScale.range([rangeFrom, rangeTo]);
          delete self.range;
        }
      };

      return self;
    };
  },
  color: (_arg: any = {}) => {
    var colors, _arg;
    colors = (_arg != null ? _arg : {}).colors;
    return () => {
      var baseScale, self;
      baseScale = d3.scale.category10();

      self = {
        domain: (segments, domain) => {
          domain = wrapLiteral(domain);

          baseScale = baseScale.domain(segments.map(domain));

          delete self.domain;
          self.use = domain;
          self.fn = scaleOverInterval(baseScale);
        },
        range: (segments, range) => {
          delete self.range;
        }
      };

      return self;
    };
  }
};
*/
