/// <reference path="../../typings/async/async.d.ts" />
"use strict";

import async = require("async");

import HigherObjectModule = require("higher-object");
import isInstanceOf = HigherObjectModule.isInstanceOf;

import chronology = require("chronology");
import Timezone = chronology.Timezone;
import Duration = chronology.Duration;

import FacetFilterModule = require("../query/filter")
import FacetFilter = FacetFilterModule.FacetFilter;
import AndFilter = FacetFilterModule.AndFilter;

import FacetSplitModule = require("../query/split");
import FacetSplit = FacetSplitModule.FacetSplit;

import FacetApplyModule = require("../query/apply");
import FacetApply = FacetApplyModule.FacetApply;

import FacetCombineModule = require("../query/combine");
import FacetCombine = FacetCombineModule.FacetCombine;

import FacetQueryModule = require("../query/query");
import FacetQuery = FacetQueryModule.FacetQuery;

import SegmentTreeModule = require("../query/segmentTree");
import SegmentTree = SegmentTreeModule.SegmentTree;
import Prop = SegmentTreeModule.Prop;

import ApplySimplifierModule = require("../query/applySimplifier");
import ApplySimplifier = ApplySimplifierModule.ApplySimplifier;
import PostProcessorScheme = ApplySimplifierModule.PostProcessorScheme;

import driverUtil = require("./driverUtil");

import Basics = require("../basics")
import Lookup = Basics.Lookup;

var arithmeticToHadoopOp: Lookup<string> = {
  add: "+",
  subtract: "-",
  multiply: "*",
  divide: "/"
};

var hadoopPostProcessorScheme: PostProcessorScheme = {
  constant: (countApply) => {
    return countApply.value;
  },
  getter: (apply) => {
    return "prop['" + apply.name + "']";
  },
  arithmetic: (arithmetic, lhs, rhs) => {
    var hadoopOp = arithmeticToHadoopOp[arithmetic];
    if (!hadoopOp) {
      throw new Error("unsupported arithmetic '" + arithmetic + "'");
    }

    if (hadoopOp === "/") {
      return "(" + rhs + " === 0 ? 0 : " + lhs + " / " + rhs + ")";
    } else {
      return "(" + lhs + " " + hadoopOp + " " + rhs + ")";
    }
  },
  finish: (name, getter) => "prop['" + name + "'] = " + getter + ";"
};

interface HadoopQueryBuilderParameters {
  timeAttribute: string;
  datasetToPath: Lookup<string>;
}

class HadoopQueryBuilder {
  public timeAttribute: string;
  public datasetToPath: Lookup<string>;
  public forceInterval: boolean;

  constructor(parameters: HadoopQueryBuilderParameters) {
    this.timeAttribute = parameters.timeAttribute;
    this.datasetToPath = parameters.datasetToPath;
    if (typeof this.datasetToPath !== "object") {
      throw new Error("must have datasetToPath mapping");
    }
    this.forceInterval = false;
  }

  public filterToHadoopHelper(filter: FacetFilter) {
    switch (filter.type) {
      case "true":
      case "false":
        return filter.type;
      case "is":
        if (filter.attribute === this.timeAttribute) {
          throw new Error("can not filter on specific time");
        }
        return "String(datum['" + filter.attribute + "']) === '" + filter.value + "'";
      case "in":
        if (filter.attribute === this.timeAttribute) {
          throw new Error("can not filter on specific time");
        }
        return filter.values.map((value) => "String(datum['" + filter.attribute + "']) === '" + value + "'").join("||");
      case "contains":
        if (filter.attribute === this.timeAttribute) {
          throw new Error("can not filter on specific time");
        }
        return "String(datum['" + filter.attribute + "']).indexOf('" + filter.value + "') !== -1";
      case "within":
        var _ref1 = filter.range;
        var r0 = _ref1[0];
        var r1 = _ref1[1];
        if (typeof r0 === "number" && typeof r1 === "number") {
          return r0 + " <= Number(datum['" + filter.attribute + "']) && Number(datum['" + filter.attribute + "']) < " + r1;
        } else {
          throw new Error("apply within has to have a numeric range");
        }
        break;
      case "not":
        return "!(" + (this.filterToHadoopHelper(filter.filter, context)) + ")";
      case "and":
        return filter.filters.map((function (filter) {
          return "(" + (this.filterToHadoopHelper(filter)) + ")";
        }), this).join("&&");
      case "or":
        return filter.filters.map((function (filter) {
          return "(" + (this.filterToHadoopHelper(filter)) + ")";
        }), this).join("||");
      default:
        throw new Error("unknown JS filter type '" + filter.type + "'");
    }
  }

  public timelessFilterToHadoop(filter) {
    return "function(datum) { return " + (this.filterToHadoopHelper(filter)) + "; }";
  }

  public addFilters(filtersByDataset) {
    var datasetName, extract, filter, timeFilter, timelessFilter;
    this.datasets = [];
    for (datasetName in filtersByDataset) {
      filter = filtersByDataset[datasetName];
      extract = filter.extractFilterByAttribute(this.timeAttribute);
      if (!extract) {
        throw new Error("could not separate time filter");
      }
      timelessFilter = extract[0], timeFilter = extract[1];

      this.datasets.push({
        name: datasetName,
        path: this.datasetToPath[datasetName],
        intervals: driverUtil.timeFilterToIntervals(timeFilter, this.forceInterval),
        filter: this.timelessFilterToHadoop(timelessFilter)
      });
    }

    return this;
  }

  public splitToHadoop(split, name) {
    var periodLength, timeBucketing, timezone;
    switch (split.bucket) {
      case "identity":
        return "t.datum['" + split.attribute + "']";
      case "continuous":
        return driverUtil.continuousFloorExpresion({
          variable: "Number(t.datum['" + split.attribute + "'])",
          floorFn: "Math.floor",
          size: split.size,
          offset: split.offset
        });
      case "timePeriod":
        timeBucketing = {
          "PT1S": 1000,
          "PT1M": 60 * 1000,
          "PT1H": 60 * 60 * 1000,
          "P1D": 24 * 60 * 60 * 1000,
          "P1W": 7 * 24 * 60 * 60 * 1000
        };
        periodLength = timeBucketing[split.period];
        if (!periodLength) {
          throw new Error("unsupported timePeriod period '" + split.period + "'");
        }

        timezone = split.timezone || "Etc/UTC";
        if (timezone !== "Etc/UTC") {
          throw new Error("unsupported timezone '" + timezone + "'");
        }
        return "new Date(Math.floor(new Date(t.datum['" + split.attribute + "']).valueOf() / " + periodLength + ") * " + periodLength + ").toISOString()";
      case "tuple":
        return "[(" + split.splits.map(this.splitToHadoop, this).join("), (") + ")].join('#$#')";
      default:
        throw new Error("bucket '" + split.bucket + "' unsupported by driver");
    }
  }

  public addSplit(split) {
    var splitName;
    if (!isInstanceOf(split, FacetSplit)) {
      throw new TypeError("split must be a FacetSplit");
    }
    splitName = split.name;
    split = split.bucket === "parallel" ? split.splits[0] : split;

    this.split = {
      name: splitName,
      fn: "function(t) { return " + (this.splitToHadoop(split)) + "; }"
    };
    return this;
  }

  public addApplies(applies: FacetApply[]) {
    var datasetName, initLines, jsPart, jsParts, loopLines, postProcessors, preLines;
    jsParts = {
      "count": {
        zero: "0",
        update: "$ += 1"
      },
      "sum": {
        zero: "0",
        update: "$ += Number(x)"
      },
      "min": {
        zero: "Infinity",
        update: "$ = Math.min($, x)"
      },
      "max": {
        zero: "-Infinity",
        update: "$ = Math.max($, x)"
      }
    };

    if (applies.length === 0) {
      return;
    }

    var applySimplifier = new ApplySimplifier({
      postProcessorScheme: hadoopPostProcessorScheme,
      breakToSimple: true,
      breakAverage: true,
      topLevelConstant: "process"
    });
    applySimplifier.addApplies(applies);

    var appliesByDataset = applySimplifier.getSimpleAppliesByDataset()
    postProcessors = applySimplifier.getPostProcessors();

    preLines = [];
    initLines = [];
    loopLines = [];
    for (datasetName in appliesByDataset) {
      applies = appliesByDataset[datasetName];
      loopLines.push("if(dataset === '" + datasetName + "') {");

      applies.forEach((apply) => {
        if (apply.aggregate === "uniqueCount") {
          preLines.push("seen['" + apply.name + "'] = {};");
          initLines.push("'" + apply.name + "': 0");
          loopLines.push("  x = datum['" + apply.attribute + "'];");
          return loopLines.push("  if(!seen['" + apply.name + "'][x]) prop['" + apply.name + "'] += (seen['" + apply.name + "'][x] = 1);");
        } else {
          jsPart = jsParts[apply.aggregate];
          if (!jsPart) {
            throw new Error("unsupported aggregate '" + apply.aggregate + "'");
          }
          initLines.push("'" + apply.name + "': " + jsPart.zero);
          if (apply.attribute) {
            loopLines.push("  x = datum['" + apply.attribute + "'];");
          }
          return loopLines.push("  " + jsPart.update.replace(/\$/g, "prop['" + apply.name + "']") + ";");
        }
      });

      loopLines.push("}");
    }

    this.applies = "function(iter) {\n  var t, x, datum, dataset, seen = {};\n  " + (preLines.join("\n  ")) + "\n  var prop = {\n    " + (initLines.join(",\n    ")) + "\n  }\n  while(iter.hasNext()) {\n    t = iter.next();\n    datum = t.datum; dataset = t.dataset;\n    " + (loopLines.join("\n    ")) + "\n  }\n  " + (postProcessors.join("\n  ")) + "\n  return prop;\n}";

    return this;
  }

  public addCombine(combine) {
    var args, cmp, sortProp;
    if (!isInstanceOf(combine, FacetCombine)) {
      throw new TypeError("combine must be a FacetCombine");
    }

    switch (combine.method) {
      case "slice":
        sortProp = combine.sort.prop;
        cmp = "a['" + sortProp + "'] < b['" + sortProp + "'] ? -1 : a['" + sortProp + "'] > b['" + sortProp + "'] ? 1 : a['" + sortProp + "'] >= b['" + sortProp + "'] ? 0 : NaN";
        args = combine.sort.direction === "ascending" ? "a, b" : "b, a";
        this.combine = {
          comparator: "function(" + args + ") { return " + cmp + "; }"
        };
        if (combine.limit != null) {
          this.combine.limit = combine.limit;
        }
        break;
      default:
        throw new Error("method '" + combine.method + "' unsupported by driver");
    }

    return this;
  }

  public getQuery() {
    if (!this.split && !this.applies) {
      return null;
    }
    var hadoopQuery = {
      options: { "mapred.job.priority": "HIGH" },
      datasets: this.datasets
    };
    if (this.split) {
      hadoopQuery.split = this.split;
    }
    hadoopQuery.applies = this.applies || "function() { return {}; }";
    if (this.combine) {
      hadoopQuery.combine = this.combine;
    }
    return hadoopQuery;
  }
}

function condensedCommandToHadoop(parameters, callback) {
  var combine, condensedCommand, e, filtersByDataset, newSegmentTree, parentSegment, queryBuilder, queryToRun, requester, split;
  requester = parameters.requester;
  queryBuilder = parameters.queryBuilder;
  parentSegment = parameters.parentSegment;
  condensedCommand = parameters.condensedCommand;
  filtersByDataset = parentSegment._filtersByDataset;

  split = condensedCommand.getSplit();
  combine = condensedCommand.getCombine();

  try {
    queryBuilder.addFilters(filtersByDataset);
    if (split) {
      queryBuilder.addSplit(split);
    }
    queryBuilder.addApplies(condensedCommand.applies);
    if (combine) {
      queryBuilder.addCombine(combine);
    }
  } catch (_error) {
    e = _error;
    callback(e);
    return;
  }

  queryToRun = queryBuilder.getQuery();
  if (!queryToRun) {
    newSegmentTree = new SegmentTree({
      prop: {}
    });
    newSegmentTree._filtersByDataset = filtersByDataset;
    callback(null, [newSegmentTree]);
    return;
  }

  requester({
    query: queryToRun
  }, (err, ds) => {
    var range, rangeStart, splitAttribute, splitDuration, splitProp, splitSize, splits, start, timezone;
    if (err) {
      callback(err);
      return;
    }

    if (split) {
      splitAttribute = split.attribute;
      splitProp = split.name;

      if (split.bucket === "continuous") {
        splitSize = split.size;
        ds.forEach((d) => {
          start = d[splitProp];
          return d[splitProp] = [start, start + splitSize];
        });
      } else if (split.bucket === "timePeriod") {
        timezone = split.timezone || "Etc/UTC";
        splitDuration = new Duration(split.period);
        ds.forEach((d) => {
          rangeStart = new Date(d[splitProp]);
          range = [rangeStart, splitDuration.move(rangeStart, timezone, 1)];
          return d[splitProp] = range;
        });
      }

      splits = ds.map((prop) => {
        newSegmentTree = new SegmentTree({
          prop: prop
        });
        newSegmentTree._filtersByDataset = FacetFilter.andFiltersByDataset(filtersByDataset, split.getFilterByDatasetFor(prop));
        return newSegmentTree;
      });
    } else {
      if (ds.length === 1) {
        newSegmentTree = new SegmentTree({
          prop: ds[0]
        });
        newSegmentTree._filtersByDataset = filtersByDataset;
        splits = [newSegmentTree];
      } else {
        callback(null, null);
        return;
      }
    }

    callback(null, splits);
  });
}

module.exports = (parameters) => {
  var filter, path, requester, timeAttribute;
  requester = parameters.requester;
  timeAttribute = parameters.timeAttribute;
  path = parameters.path;
  filter = parameters.filter;
  if (typeof requester !== "function") {
    throw new Error("must have a requester");
  }
  if (typeof path !== "string") {
    throw new Error("must have path");
  }
  timeAttribute || (timeAttribute = "time");

  return (request, callback) => {
    if (!request) {
      callback(new Error("request not supplied"));
      return;
    }
    var context = request.context || {};
    var query = request.query;

    if (!FacetQuery.isFacetQuery(query)) {
      callback(new TypeError("query must be a FacetQuery"));
      return;
    }

    var datasetToPath = {};
    query.getDatasets().forEach((dataset) => datasetToPath[dataset.name] = dataset.source);

    var init = true;
    var rootSegment = new SegmentTree({
      prop: {}
    }, { filtersByDataset: query.getFiltersByDataset(filter) });
    var segments = [rootSegment]

    var condensedGroups = query.getCondensedCommands()

    function querySQL(condensedCommand, callback) {
      var QUERY_LIMIT, queryFns, segmentFilterFn;
      QUERY_LIMIT = 10;

      if (condensedCommand.split != null ? condensedCommand.split.segmentFilter : void 0) {
        segmentFilterFn = condensedCommand.split.segmentFilter.getFilterFn();
        driverUtil.inPlaceFilter(segments, segmentFilterFn);
      }

      queryFns = async.mapLimit(segments, QUERY_LIMIT, (parentSegment, callback) => condensedCommandToHadoop({
        requester: requester,
        queryBuilder: new HadoopQueryBuilder({
          timeAttribute: timeAttribute,
          datasetToPath: datasetToPath
        }),
        parentSegment: parentSegment,
        condensedCommand: condensedCommand
      }, (err, splits) => {
        if (err) {
          callback(err);
          return;
        }

        if (splits === null) {
          callback(null, null);
          return;
        }
        parentSegment.setSplits(splits);
        return callback(null, parentSegment.splits);
      }), (err, results) => {
        if (err) {
          callback(err);
          return;
        }

        if (results.some((result) => result === null)) {
          rootSegment = null;
        } else {
          segments = driverUtil.flatten(results);
          if (init) {
            rootSegment = segments[0];
            init = false;
          }
        }

        callback();
      });
    }

    var cmdIndex = 0;
    return async.whilst(() => cmdIndex < condensedGroups.length && rootSegment, (callback) => {
      var condensedGroup = condensedGroups[cmdIndex];
      cmdIndex++;
      querySQL(condensedGroup, callback);
    }, (err) => {
      if (err) {
        callback(err);
        return;
      }

      callback(null, (rootSegment || new SegmentTree({})).selfClean());
    });
  };
};
