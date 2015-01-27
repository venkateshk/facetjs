"use strict";

import Basics = require("../basics") // Prop up
import Lookup = Basics.Lookup;
import Datum = Basics.Datum;

import HigherObjectModule = require("higher-object");
import isInstanceOf = HigherObjectModule.isInstanceOf;

import chronology = require("chronology");
import Duration = chronology.Duration;

import FacetFilterModule = require("../query/filter")
import FacetFilter = FacetFilterModule.FacetFilter;

import FacetSplitModule = require("../query/split");
import FacetSplit = FacetSplitModule.FacetSplit;
import IdentitySplit = FacetSplitModule.IdentitySplit;
import ContinuousSplit = FacetSplitModule.ContinuousSplit;
import TimePeriodSplit = FacetSplitModule.TimePeriodSplit;
import TupleSplit = FacetSplitModule.TupleSplit;
import ParallelSplit = FacetSplitModule.ParallelSplit;

import FacetApplyModule = require("../query/apply");
import FacetApply = FacetApplyModule.FacetApply;
import ConstantApply = FacetApplyModule.ConstantApply;
import CountApply = FacetApplyModule.CountApply;
import SumApply = FacetApplyModule.SumApply;
import AverageApply = FacetApplyModule.AverageApply;
import MinApply = FacetApplyModule.MinApply;
import MaxApply = FacetApplyModule.MaxApply;
import UniqueCountApply = FacetApplyModule.UniqueCountApply;
import QuantileApply = FacetApplyModule.QuantileApply;

import FacetCombineModule = require("../query/combine");
import FacetCombine = FacetCombineModule.FacetCombine;
import SliceCombine = FacetCombineModule.SliceCombine;
import MatrixCombine = FacetCombineModule.MatrixCombine;

import FacetQueryModule = require("../query/query");
import FacetQuery = FacetQueryModule.FacetQuery;

import driverUtil = require("./driverUtil");

import SegmentTreeModule = require("../query/segmentTree");
import SegmentTree = SegmentTreeModule.SegmentTree;
import Prop = SegmentTreeModule.Prop;

import Driver = require("../driverCommon")


interface SplitFn {
  (d: Datum): any;
}

interface SplitFnFactory {
  (split: FacetSplit): SplitFn;
}

var splitFnFactories: Lookup<SplitFnFactory> = {};
splitFnFactories['identity'] = (split: IdentitySplit): SplitFn => {
  var attribute = split.attribute;
  return (d: Datum) => {
    var value = d[attribute];
    return value != null ? value : null;
  };
};
splitFnFactories['continuous'] = (split: ContinuousSplit): SplitFn => {
  var attribute = split.attribute;
  var size = split.size;
  var offset = split.offset;
  return (d: Datum) => {
    var num = Number(d[attribute]);
    if (isNaN(num)) {
      return null;
    }
    var b = Math.floor((num - offset) / size) * size + offset;
    return [b, b + size];
  };
};
splitFnFactories['timePeriod'] = (split: TimePeriodSplit): SplitFn => {
  var attribute = split.attribute;
  var period = split.period;
  var timezone = split.timezone;
  var warp = split.warp;
  var warpDirection = split.warpDirection;
  return (d: Datum) => {
    var ds = new Date(d[attribute]);
    if (isNaN(ds.valueOf())) return null;
    ds = period.floor(ds, timezone);
    var de = period.move(ds, timezone, 1);
    if (warp) {
      ds = warp.move(ds, timezone, warpDirection);
      de = warp.move(de, timezone, warpDirection);
    }
    return [ds, de];
  };
};
splitFnFactories['tuple'] = (split: TupleSplit): SplitFn => {
  var splits = split.splits;
  var tupleSplits = splits.map(makeSplitFn);
  return (d: Datum) => tupleSplits.map((sf) => sf(d));
};
function makeSplitFn(split: FacetSplit): SplitFn {
  if (!isInstanceOf(split, FacetSplit)) {
    throw new TypeError("split must be a FacetSplit");
  }
  var splitFnFactory = (<any>splitFnFactories)[split.bucket];
  if (!splitFnFactory) {
    throw new Error("split bucket '" + split.bucket + "' not supported by driver");
  }
  return splitFnFactory(split);
}

// ------------------------------------------

interface SingleDatasetApplyFn {
  (ds: Datum[]): number;
}

interface MultiDatasetApplyFn {
  (ds: Lookup<Datum[]>): number;
}

interface SingleDatasetApplyFnFactory {
  (split: FacetApply): SingleDatasetApplyFn;
}

var aggregateFns: Lookup<SingleDatasetApplyFnFactory> = {
  constant: (apply: ConstantApply) => {
    var value = apply.value;
    return (ds: Datum[]) => Number(value);
  },
  count: (apply: CountApply) => {
    return (ds: Datum[]) => ds.length;
  },
  sum: (apply: SumApply) => {
    var attribute = apply.attribute;
    return (ds: Datum[]) => {
      var sum = 0;
      ds.forEach((d) => sum += Number(d[attribute]));
      return sum;
    };
  },
  average: (apply: AverageApply) => {
    var attribute = apply.attribute;
    return (ds: Datum[]) => {
      var sum = 0;
      ds.forEach((d) => sum += Number(d[attribute]));
      return sum / ds.length;
    };
  },
  min: (apply: MinApply) => {
    var attribute = apply.attribute;
    return (ds: Datum[]) => {
      var min = +Infinity;
      ds.forEach((d) => min = Math.min(min, Number(d[attribute])));
      if (isNaN(min)) {
        min = +Infinity;
        ds.forEach((d) => min = Math.min(min, (new Date(d[attribute])).valueOf()));
      }
      return min;
    };
  },
  max: (apply: MaxApply) => {
    var attribute = apply.attribute;
    return (ds: Datum[]) => {
      var max = -Infinity;
      ds.forEach((d) => max = Math.max(max, Number(d[attribute])));
      if (isNaN(max)) {
        max = -Infinity;
        ds.forEach((d) => max = Math.max(max, (new Date(d[attribute])).valueOf()));
      }
      return max;
    };
  },
  uniqueCount: (apply: UniqueCountApply) => {
    var attribute = apply.attribute;
    return (ds: Datum[]) => {
      var seen: any = {};
      var count = 0;
      ds.forEach((d) => {
        var v = d[attribute];
        if (!seen[v]) {
          count++;
          return seen[v] = 1;
        }
      });
      return count;
    };
  },
  quantile: (apply: QuantileApply) => {
    var attribute = apply.attribute;
    var quantile = apply.quantile;
    return (ds: Datum[]) => {
      if (!ds.length) return null;
      var points = ds.map((d) => Number(d[attribute]));
      points.sort((a, b) => a - b);
      return points[Math.floor(points.length * quantile)];
    };
  }
};

var arithmeticFns: Lookup<Function> = {
  add: (lhs: Function, rhs: Function) => {
    return (x: any) => lhs(x) + rhs(x);
  },
  subtract: (lhs: Function, rhs: Function) => {
    return (x: any) => lhs(x) - rhs(x);
  },
  multiply: (lhs: Function, rhs: Function) => {
    return (x: any) => lhs(x) * rhs(x);
  },
  divide: (lhs: Function, rhs: Function) => {
    return (x: any) => lhs(x) / rhs(x);
  }
};

function makeApplyFn(apply: FacetApply): MultiDatasetApplyFn {
  if (!isInstanceOf(apply, FacetApply)) {
    throw new TypeError("apply must be a FacetApply");
  }
  if (apply.aggregate) {
    var aggregateFn = aggregateFns[apply.aggregate];
    if (!aggregateFn) {
      throw new Error("aggregate '" + apply.aggregate + "' unsupported by driver");
    }
    var dataset = apply.getDataset();
    var rawApplyFn = aggregateFn(apply);
    if (apply.filter) {
      var filterFn = apply.filter.getFilterFn();
      return (dss) => rawApplyFn(dss[dataset].filter(filterFn));
    } else {
      return (dss) => rawApplyFn(dss[dataset]);
    }
  } else if (apply.arithmetic) {
    var arithmeticFn = arithmeticFns[apply.arithmetic];
    if (!arithmeticFn) {
      throw new Error("arithmetic '" + apply.arithmetic + "' unsupported by driver");
    }
    var operands = apply.operands;
    return arithmeticFn(makeApplyFn(operands[0]), makeApplyFn(operands[1]));
  } else {
    throw new Error("apply must have an aggregate or an arithmetic");
  }
}

// -------------------------------------------------------

interface CombineFn {
  (ds: SegmentTree[]): void;
}

interface CombineFnFactory {
  (combine: FacetCombine): CombineFn;
}

var combineFns: Lookup<CombineFnFactory> = {
  slice: (combine: SliceCombine) => {
    var sort = combine.sort;
    var limit = combine.limit;
    if (sort) {
      var segmentCompareFn = sort.getSegmentCompareFn();
    }

    return (segments) => {
      if (segmentCompareFn) {
        segments.sort(segmentCompareFn);
      }

      if (limit != null) {
        driverUtil.inPlaceTrim(segments, limit);
      }
    };
  },
  matrix: (combine: MatrixCombine) => {
    return (segments) => {
      throw new Error("matrix combine not implemented yet");
    };
  }
};

function makeCombineFn(combine: FacetCombine) {
  if (!isInstanceOf(combine, FacetCombine)) {
    throw new TypeError("combine must be a FacetCombine");
  }
  var combineFn = combineFns[combine.method];
  if (!combineFn) {
    throw new Error("method '" + combine.method + "' unsupported by driver");
  }
  return combineFn(combine);
}

function computeQuery(data: Datum[], query: FacetQuery): SegmentTree {
  var applyFn: any;
  var combineFn: any;
  var datasetName: any;
  var segmentFilterFn: any;

  var rootRaw: Lookup<Datum[]> = {};

  var filtersByDataset = query.getFiltersByDataset();
  for (datasetName in filtersByDataset) {
    var datasetFilter = filtersByDataset[datasetName];
    rootRaw[datasetName] = data.filter(datasetFilter.getFilterFn());
  }

  var rootSegment = new SegmentTree({
    prop: <Prop>{}
  }, { raws: rootRaw });
  var segmentGroups = [[rootSegment]];
  var originalSegmentGroups = segmentGroups;

  var groups = query.getCondensedCommands();
  groups.forEach((condensedCommand) => {
    var split = condensedCommand.getSplit();
    var applies = condensedCommand.getApplies();
    var combine = condensedCommand.getCombine();

    if (split) {
      var propName = split.name;
      var parallelSplits = split.bucket === "parallel" ? (<ParallelSplit>split).splits : [split];

      var parallelSplitFns: Lookup<SplitFn> = {};
      parallelSplits.forEach((parallelSplit) => {
        parallelSplitFns[parallelSplit.getDataset()] = makeSplitFn(parallelSplit);
      });

      segmentFilterFn = split.segmentFilter ? split.segmentFilter.getFilterFn() : null;
      segmentGroups = driverUtil.filterMap(driverUtil.flatten(segmentGroups), (segment) => {
        if (segmentFilterFn && !segmentFilterFn(segment)) {
          return;
        }
        var keys: any[] = [];
        var bucketsByDataset: Lookup<Lookup<Datum[]>> = {};
        var bucketValue: Lookup<any> = {};
        for (var dataset in parallelSplitFns) {
          var parallelSplitFn = parallelSplitFns[dataset];
          var buckets: Lookup<Datum[]> = {};
          segment.meta['raws'][dataset].forEach((d: Datum) => {
            var key = parallelSplitFn(d);
            var keyString = String(key);

            if (!bucketValue.hasOwnProperty(keyString)) {
              keys.push(keyString);
              bucketValue[keyString] = key;
            }

            if (!buckets[keyString]) {
              buckets[keyString] = [];
            }
            return buckets[keyString].push(d);
          });
          bucketsByDataset[dataset] = buckets;
        }

        segment.setSplits(keys.map((keyString) => {
          var prop: Prop = {};
          prop[propName] = bucketValue[keyString];

          var raws: Lookup<Datum[]> = {};
          for (dataset in bucketsByDataset) {
            buckets = bucketsByDataset[dataset];
            raws[dataset] = buckets[keyString] || [];
          }

          var newSplit = new SegmentTree({
            prop: prop
          }, { raws: raws });
          return newSplit;
        }));

        return segment.splits;
      });
    }

    applies.forEach((apply) => {
      propName = apply.name;
      var applyFn = makeApplyFn(apply);
      return segmentGroups.map((segmentGroup) => {
        segmentGroup.map((segment) => {
          // ToDo: remove <any> when union types
          segment.prop[propName] = <any>applyFn(segment.meta['raws']);
        });
      });
    });

    if (combine) {
      var combineFn = makeCombineFn(combine);
      segmentGroups.forEach(combineFn);
    }
  });

  return (originalSegmentGroups[0][0] || new SegmentTree({})).selfClean();
}

interface IntrospectOptions {
  maxSample?: number;
  maxYear?: number;
}
function introspectData(data: Datum[], options: IntrospectOptions): Driver.AttributeIntrospect[] {
  var maxSample = options.maxSample;
  var maxYear = options.maxYear || (new Date().getUTCFullYear() + 5);
  if (!data.length) return null;
  var sample = data.slice(0, maxSample);

  var attributeNames: string[] = [];
  for (var k in sample[0]) {
    if (k === "") continue;
    attributeNames.push(k);
  }
  attributeNames.sort();

  function isDate(dt: any) {
    dt = new Date(dt);
    if (isNaN(dt.valueOf())) return false;
    var year = dt.getUTCFullYear();
    return 1987 <= year && year <= maxYear;
  }

  function isNumber(n: any) {
    return !isNaN(Number(n));
  }

  function isInteger(n: any) {
    return Number(n) === parseInt(n, 10);
  }

  function isString(str: string) {
    return typeof str === "string";
  }

  return attributeNames.map((attributeName) => {
    var attribute: Driver.AttributeIntrospect = {
      name: attributeName
    };
    var column = sample.map((d) => d[attributeName]).filter((x) => x !== null && x !== "");
    if (column.length) {
      if (column.every(isDate)) {
        attribute.time = true;
      }

      if (column.every(isNumber)) {
        attribute.numeric = true;
        if (column.every(isInteger)) {
          attribute.integer = true;
        }
      } else {
        if (column.every(isString)) {
          attribute.categorical = true;
        }
      }
    }

    return attribute;
  });
}

export function simpleDriver(dataGetter: any): Driver.FacetDriver {
  var dataError: Error = null;
  var dataArray: Datum[] = null;

  if (Array.isArray(dataGetter)) {
    dataArray = dataGetter;
  } else if (typeof dataGetter === "function") {
    var waitingQueries: Function[] = [];
    dataGetter((err: Error, data: Datum[]) => {
      dataError = err;
      dataArray = data;
      waitingQueries.forEach((waitingQuery) => waitingQuery());
      waitingQueries = null;
    });
  } else {
    throw new TypeError("dataGetter must be a function or raw data (array)");
  }

  var driver: any = (request: Driver.Request, callback: Driver.DataCallback): void => {
    if (!request) {
      callback(new Error("request not supplied"));
      return;
    }

    var query = request.query;
    if (!FacetQuery.isFacetQuery(query)) {
      callback(new TypeError("query must be a FacetQuery"));
      return;
    }

    function computeWithData() {
      if (dataError) {
        callback(dataError);
        return;
      }

      try {
        var result = computeQuery(dataArray, query);
      } catch (error) {
        callback(error);
        return;
      }

      callback(null, result);
    }

    if (waitingQueries) {
      waitingQueries.push(computeWithData);
    } else {
      computeWithData();
    }

  };

  driver.introspect = (opts: any, callback: Driver.IntrospectionCallback) => {
    var maxSample = (opts || {}).maxSample;

    function doIntrospect() {
      if (dataError) {
        callback(dataError);
        return;
      }

      var attributes = introspectData(dataArray, {
        maxSample: maxSample || 1000
      });

      callback(null, attributes);
    }

    if (waitingQueries) {
      waitingQueries.push(doIntrospect);
    } else {
      doIntrospect();
    }

  };

  return driver;
}
