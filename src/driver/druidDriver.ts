/// <reference path="../../typings/async/async.d.ts" />
/// <reference path="../../definitions/druid.d.ts" />
"use strict";

import Basics = require("../basics") // Prop up
import Lookup = Basics.Lookup;

import async = require("async");

import chronology = require("chronology");
import Duration = chronology.Duration;

import AttributeMetaModule = require("../query/attributeMeta");
import AttributeMeta = AttributeMetaModule.AttributeMeta;
import UniqueAttributeMeta = AttributeMetaModule.UniqueAttributeMeta;
import HistogramAttributeMeta = AttributeMetaModule.HistogramAttributeMeta;
import RangeAttributeMeta = AttributeMetaModule.RangeAttributeMeta;

import FacetFilterModule = require("../query/filter")
import FacetFilter = FacetFilterModule.FacetFilter;
import FiltersByDataset = FacetFilterModule.FiltersByDataset;
import IsFilter = FacetFilterModule.IsFilter;
import InFilter = FacetFilterModule.InFilter;
import WithinFilter = FacetFilterModule.WithinFilter;
import MatchFilter = FacetFilterModule.MatchFilter;
import ContainsFilter = FacetFilterModule.ContainsFilter;
import NotFilter = FacetFilterModule.NotFilter;
import AndFilter = FacetFilterModule.AndFilter;
import OrFilter = FacetFilterModule.OrFilter;

import FacetSplitModule = require("../query/split");
import FacetSplit = FacetSplitModule.FacetSplit;
import ContinuousSplit = FacetSplitModule.ContinuousSplit;
import TimePeriodSplit = FacetSplitModule.TimePeriodSplit;
import TupleSplit = FacetSplitModule.TupleSplit;
import ParallelSplit = FacetSplitModule.ParallelSplit;

import FacetApplyModule = require("../query/apply");
import FacetApply = FacetApplyModule.FacetApply;
import CountApply = FacetApplyModule.CountApply;
import QuantileApply = FacetApplyModule.QuantileApply;

import FacetCombineModule = require("../query/combine");
import FacetCombine = FacetCombineModule.FacetCombine;
import SliceCombine = FacetCombineModule.SliceCombine;
import MatrixCombine = FacetCombineModule.MatrixCombine;

import CondensedCommandModule = require("../query/condensedCommand");
import CondensedCommand = CondensedCommandModule.CondensedCommand;

import FacetQueryModule = require("../query/query");
import FacetQuery = FacetQueryModule.FacetQuery;

import SegmentTreeModule = require("../query/segmentTree");
import SegmentTree = SegmentTreeModule.SegmentTree;
import Prop = SegmentTreeModule.Prop;

import ApplySimplifierModule = require("../query/applySimplifier");
import ApplySimplifier = ApplySimplifierModule.ApplySimplifier;
import PostProcessorScheme = ApplySimplifierModule.PostProcessorScheme;

import driverUtil = require("./driverUtil");

import Requester = require("../requesterCommon");
import Driver = require("../driverCommon");

function isString(str: any): boolean {
  return typeof str === "string";
}

var arithmeticToDruidFn: Lookup<string> = {
  add: "+",
  subtract: "-",
  multiply: "*",
  divide: "/"
};

var druidPostProcessorScheme: PostProcessorScheme<Druid.PostAggregation, Druid.PostAggregation> = {
  constant: (constantApply) => {
    var value = constantApply.value;
    return {
      type: "constant",
      value: value
    };
  },
  getter: (aggregateApply) => {
    var name = aggregateApply.name;
    var aggregate = aggregateApply.aggregate;
    return {
      type: aggregate === "uniqueCount" ? "hyperUniqueCardinality" : "fieldAccess",
      fieldName: name
    };
  },
  arithmetic: (arithmetic, lhs, rhs) => {
    var druidFn = arithmeticToDruidFn[arithmetic];
    if (!druidFn) {
      throw new Error("unsupported arithmetic '" + arithmetic + "'");
    }

    return {
      type: "arithmetic",
      fn: druidFn,
      fields: [lhs, rhs]
    };
  },
  finish: (name, getter) => {
    getter.name = name;
    return getter;
  }
};

var aggregateToJS: Lookup<any> = { // ToDo: better typing here;
  count: ["0", (a: string, b: string) => a + " + " + b],
  sum: ["0", (a: string, b: string) => a + " + " + b],
  min: ["Infinity", (a: string, b: string) => "Math.min(" + a + ", " + b + ")"],
  max: ["-Infinity", (a: string, b: string) => "Math.max(" + a + ", " + b + ")"]
};

function correctSingletonDruidResult(result: any): boolean {
  return Array.isArray(result) && result.length <= 1 && (result.length === 0 || result[0].result);
}

function emptySingletonDruidResult(result: any): boolean {
  return result.length === 0;
}

export interface QueryFunctionParameters {
  requester: Requester.FacetRequester<Druid.Query>;
  queryBuilder: DruidQueryBuilder;
  filter: FacetFilter;
  parentSegment: SegmentTree;
  condensedCommand: CondensedCommand;
}

export interface QueryFunctionCallback {
  (error: Error, props?: Prop[]): void;
}

export interface QueryFunction {
  (parameters: QueryFunctionParameters, callback: QueryFunctionCallback): void;
}

export interface DruidQueryBuilderParameters {
  dataSource: any; // ToDo: string | string[]
  timeAttribute: string;
  attributeMetas: Lookup<AttributeMeta>;
  forceInterval: boolean;
  approximate: boolean;
  context: any;
}

export class DruidQueryBuilder {
  static ALL_DATA_CHUNKS = 10000;
  static FALSE_INTERVALS = ["1000-01-01/1000-01-02"];
  static queryFns: Lookup<QueryFunction>;

  static makeSingleQuery(parameters: QueryFunctionParameters, callback: QueryFunctionCallback): void {
    var condensedCommand = parameters.condensedCommand;
    var queryBuilder = parameters.queryBuilder;
    var timeAttribute = queryBuilder.timeAttribute;
    var approximate = queryBuilder.approximate;

    var queryFnName: string;
    var split = condensedCommand.getSplit()
    if (split) {
      switch (split.bucket) {
        case "identity":
          if (approximate) {
            if ((<SliceCombine>(condensedCommand.getCombine())).limit != null) {
              queryFnName = "topN";
            } else {
              queryFnName = "allData";
            }
          } else {
            queryFnName = "groupBy";
          }
          break;
        case "timePeriod":
          queryFnName = "timeseries";
          break;
        case "continuous":
          var attributeMeta = queryBuilder.getAttributeMeta(split.attribute)
          if (attributeMeta.type === "histogram") {
            queryFnName = "histogram";
          } else {
            queryFnName = "topN";
          }
          break;
        case "tuple":
          if (approximate && ((<TupleSplit>split).splits).length === 2) {
            queryFnName = "heatmap";
          } else {
            queryFnName = "groupBy";
          }
          break;
        default:
          var err = new Error("unsupported split bucket");
          (<any>err).split = split.valueOf();
          callback(err);
          return;
      }
    } else {
      if (condensedCommand.applies.some((apply) => apply.attribute === timeAttribute && (apply.aggregate === "min" || apply.aggregate === "max"))) {
        queryFnName = "timeBoundary";
      } else {
        queryFnName = "all";
      }
    }

    var queryFn = DruidQueryBuilder.queryFns[queryFnName];
    queryFn(parameters, callback);
  }

  public dataSource: any; // ToDo: string | Druid.Datasource;
  public queryType: string = "timeseries";
  public timeAttribute: string;
  public attributeMetas: { [attributeName: string]: AttributeMeta };
  public forceInterval: boolean;
  public intervals: string[];
  public approximate: boolean;
  public granularity: any; // ToDo: string | Druid.Granularity;
  public filter: Druid.Filter = null;
  public aggregations: Druid.Aggregation[] = [];
  public postAggregations: Druid.PostAggregation[] = [];
  public dimension: Druid.DimensionSpec;
  public dimensions: any[];
  public metric: any; // ToDo: string | Druid.TopNMetricSpec;
  public threshold: number;
  public context: Druid.Context;

  private nameIndex: number = 0;
  private jsCount: number = 0;

  constructor(parameters: DruidQueryBuilderParameters) {
    this.setDataSource(parameters.dataSource);
    this.timeAttribute = parameters.timeAttribute || 'timestamp';
    if (!isString(this.timeAttribute)) throw new Error("must have a timeAttribute");
    this.attributeMetas = parameters.attributeMetas;
    this.forceInterval = parameters.forceInterval;
    this.approximate = parameters.approximate;
    this.granularity = "all";
    this.intervals = null;

    var parametersContext = parameters.context;
    var context: Druid.Context = {};
    for (var k in parametersContext) {
      if (!parametersContext.hasOwnProperty(k)) continue;
      context[k] = parametersContext[k];
    }
    this.context = context;
  }

  public setDataSource(dataSource: any): void { // ToDo: string | string[]
    if (!(isString(dataSource) || (Array.isArray(dataSource) && dataSource.length && dataSource.every(isString)))) {
      throw new Error("`dataSource` must be a string or union array");
    }

    if (isString(dataSource)) {
      this.dataSource = dataSource;
    } else {
      this.dataSource = {
        type: "union",
        dataSources: dataSource
      };
    }
  }

  public getAttributeMeta(attribute: string): AttributeMeta {
    if (this.attributeMetas[attribute]) {
      return this.attributeMetas[attribute];
    }
    if (/_hist$/.test(attribute)) {
      return AttributeMeta.HISTOGRAM;
    }
    if (/^unique_/.test(attribute)) {
      return AttributeMeta.UNIQUE;
    }
    return AttributeMeta.DEFAULT;
  }

  public addToNamespace(namespace: Lookup<string>, attribute: string) {
    if (namespace[attribute]) {
      return namespace[attribute];
    }
    namespace[attribute] = "v" + this.jsCount;
    this.jsCount++;
    return namespace[attribute];
  }

  public filterToJSHelper(filter: FacetFilter, namespace: Lookup<string>): string {
    var attributeMeta: AttributeMeta;
    var varName: string;
    switch (filter.type) {
      case "true":
      case "false":
        return filter.type;
      case "is":
        if (filter.attribute === this.timeAttribute) throw new Error("can not filter on specific time");
        attributeMeta = this.getAttributeMeta(filter.attribute);
        varName = this.addToNamespace(namespace, filter.attribute);
        return varName + " === '" + (attributeMeta.serialize((<IsFilter>filter).value)) + "'";
      case "in":
        if (filter.attribute === this.timeAttribute) throw new Error("can not filter on specific time");
        attributeMeta = this.getAttributeMeta(filter.attribute);
        varName = this.addToNamespace(namespace, filter.attribute);
        return (<InFilter>filter).values.map((value) => {
          return varName + " === '" + (attributeMeta.serialize(value)) + "'"
        }).join("||");
      case "contains":
        if (filter.attribute === this.timeAttribute) throw new Error("can not filter on specific time");
        varName = this.addToNamespace(namespace, filter.attribute);
        return "String(" + varName + ").indexOf('" + (<ContainsFilter>filter).value + "') !== -1";
      case "not":
        return "!(" + (this.filterToJSHelper((<NotFilter>filter).filter, namespace)) + ")";
      case "and":
        return (<AndFilter>filter).filters.map((filter) => {
          return "(" + (this.filterToJSHelper(filter, namespace)) + ")";
        }, this).join("&&");
      case "or":
        return (<OrFilter>filter).filters.map((filter) => {
          return "(" + (this.filterToJSHelper(filter, namespace)) + ")";
        }, this).join("||");
      default:
        throw new Error("unknown JS filter type '" + filter.type + "'");
    }
  }

  public filterToJS(filter: FacetFilter) {
    var namespace: Lookup<string> = {}
    this.jsCount = 0;
    var jsFilter = this.filterToJSHelper(filter, namespace)
    return {
      jsFilter: jsFilter,
      namespace: namespace
    };
  }

  public timelessFilterToDruid(filter: FacetFilter): Druid.Filter {
    var attributeMeta: AttributeMeta;
    switch (filter.type) {
      case "true":
        return null;
      case "false":
        throw new Error("should never get here");
        break;
      case "is":
        attributeMeta = this.getAttributeMeta(filter.attribute);
        return {
          type: "selector",
          dimension: filter.attribute,
          value: attributeMeta.serialize((<IsFilter>filter).value)
        };
      case "in":
        attributeMeta = this.getAttributeMeta(filter.attribute);
        return {
          type: "or",
          fields: (<InFilter>filter).values.map(((value: any) => ({ // ToDo: Do we need the any?
            type: "selector",
            dimension: filter.attribute,
            value: attributeMeta.serialize(value)
          })), this)
        };
      case "contains":
        return {
          type: "search",
          dimension: filter.attribute,
          query: {
            type: "fragment",
            values: [(<ContainsFilter>filter).value]
          }
        };
      case "match":
        return {
          type: "regex",
          dimension: filter.attribute,
          pattern: (<MatchFilter>filter).expression
        };
      case "within":
        var range = (<WithinFilter>filter).range;
        var r0 = range[0];
        var r1 = range[1];
        if (typeof r0 !== "number" || typeof r1 !== "number") {
          throw new Error("apply within has to have a numeric range");
        }
        return {
          type: "javascript",
          dimension: filter.attribute,
          "function": "function(a) { a = Number(a); return " + r0 + " <= a && a < " + r1 + "; }"
        };
      case "not":
        return {
          type: "not",
          field: this.timelessFilterToDruid((<NotFilter>filter).filter)
        };
      case "and":
      case "or":
        return {
          type: filter.type,
          fields: (<AndFilter>filter).filters.map(this.timelessFilterToDruid, this)
        };
      default:
        throw new Error("filter type '" + filter.type + "' not defined");
    }
  }

  public addFilter(filter: FacetFilter): DruidQueryBuilder {
    if (filter.type === "false") {
      this.intervals = DruidQueryBuilder.FALSE_INTERVALS;
      this.filter = null;
    } else {
      var extract = filter.extractFilterByAttribute(this.timeAttribute);
      if (!extract) {
        throw new Error("could not separate time filter");
      }
      var timelessFilter = extract[0];
      var timeFilter = extract[1];

      this.intervals = driverUtil.timeFilterToIntervals(timeFilter, this.forceInterval);
      this.filter = this.timelessFilterToDruid(timelessFilter);
    }

    return this;
  }

  public addSplit(split: FacetSplit) {
    if (!FacetSplit.isFacetSplit(split)) throw new TypeError('must be a split');
    switch (split.bucket) {
      case "identity":
        this.queryType = "groupBy";
        var attributeMeta = this.getAttributeMeta(split.attribute)
        if (attributeMeta.type === "range") {
          var regExp = (<RangeAttributeMeta>attributeMeta).getMatchingRegExpString()
          this.dimension = {
            type: "extraction",
            dimension: split.attribute,
            outputName: split.name,
            dimExtractionFn: {
              type: "javascript",
              "function": "function(d) {" +
                "var match = d.match(" + regExp + ");" +
                "if(!match) return 'null';" +
                "var start = +match[1], end = +match[2];" +
                "if(!(Math.abs(end - start - " + (<RangeAttributeMeta>attributeMeta).rangeSize + ") < 1e-6)) return 'null';" +
                "var parts = String(Math.abs(start)).split('.');" +
                "parts[0] = ('000000000' + parts[0]).substr(-10);" +
                "return (start < 0 ?'-':'') + parts.join('.');" +
                "}"
            }
          };
        } else {
          this.dimension = {
            type: "default",
            dimension: split.attribute,
            outputName: split.name
          };
        }
        break;

      case "timePeriod":
        if (split.attribute !== this.timeAttribute) {
          throw new Error("timePeriod split can only work on '" + this.timeAttribute + "'");
        }
        this.granularity = {
          type: "period",
          period: (<TimePeriodSplit>split).period,
          timeZone: (<TimePeriodSplit>split).timezone
        };
        break;

      case "continuous":
        attributeMeta = this.getAttributeMeta(split.attribute);
        if (attributeMeta.type === "histogram") {
          if (!this.approximate) {
            throw new Error("approximate queries not allowed");
          }
          var aggregation: Druid.Aggregation = {
            type: "approxHistogramFold",
            fieldName: split.attribute
          }
          if ((<ContinuousSplit>split).lowerLimit != null) {
            aggregation.lowerLimit = (<ContinuousSplit>split).lowerLimit;
          }
          if ((<ContinuousSplit>split).upperLimit != null) {
            aggregation.upperLimit = (<ContinuousSplit>split).upperLimit;
          }
          var options = split.options || {};
          if (options.hasOwnProperty('druidResolution')) {
            aggregation.resolution = options['druidResolution'];
          }
          this.addAggregation(aggregation);
          var tempHistogramName = 'blah'; // ToDo: OMG WTF ?!
            this.addPostAggregation({
            type: "buckets",
            name: "histogram",
            fieldName: tempHistogramName,
            bucketSize: (<ContinuousSplit>split).size,
            offset: (<ContinuousSplit>split).offset
          });
        } else if (attributeMeta.type === "range") {
          throw new Error("not implemented yet");
        } else {
          var floorExpression = driverUtil.continuousFloorExpression("d", "Math.floor", (<ContinuousSplit>split).size, (<ContinuousSplit>split).offset)

          this.queryType = "groupBy";
          this.dimension = {
            type: "extraction",
            dimension: split.attribute,
            outputName: split.name,
            dimExtractionFn: {
              type: "javascript",
              "function": "function(d) {\nd = Number(d);\nif(isNaN(d)) return 'null';\nreturn " + floorExpression + ";\n}"
            }
          };
        }
        break;

      case "tuple":
        var splits = (<TupleSplit>split).splits;
        if (splits.length !== 2) throw new Error("only supported tuples of size 2 (is: " + splits.length + ")");
        this.queryType = "heatmap";
        this.dimensions = splits.map((split) => ({
          dimension: split.attribute,
          threshold: 10
        }));
        break;

      default:
        throw new Error("unsupported bucketing function");
    }

    return this;
  }

  public addAggregation(aggregation: Druid.Aggregation): void {
    var aggregations = this.aggregations;
    for (var i = 0; i < aggregations.length; i++) {
      var existingAggregation = aggregations[i];
      if (existingAggregation.name === aggregation.name) return;
    }
    this.aggregations.push(aggregation);
  }

  public addPostAggregation(postAggregation: Druid.PostAggregation): void {
    this.postAggregations.push(postAggregation);
  }

  public canUseNativeAggregateFilter(filter: FacetFilter) {
    if (!filter) return true;
    return filter.type === 'is' || (filter.type === 'not' && (<NotFilter>filter).filter.type === 'is');
  }

  public addAggregateApply(apply: FacetApply) {
    if (apply.attribute === this.timeAttribute) throw new Error("can not aggregate apply on time attribute");

    var attributeMeta = this.getAttributeMeta(apply.attribute);
    var options = apply.options || {};
    switch (apply.aggregate) {
      case "count":
      case "sum":
      case "min":
      case "max":
        if (this.approximate && apply.aggregate[0] === "m" && attributeMeta.type === "histogram") { // min & max
          var histogramAggregationName = "_hist_" + apply.attribute;
          var aggregation: Druid.Aggregation = {
            name: histogramAggregationName,
            type: "approxHistogramFold",
            fieldName: apply.attribute
          };
          if (options.hasOwnProperty('druidLowerLimit')) aggregation.lowerLimit = options['druidLowerLimit'];
          if (options.hasOwnProperty('druidUpperLimit')) aggregation.upperLimit = options['druidUpperLimit'];
          if (options.hasOwnProperty('druidResolution')) aggregation.resolution = options['druidResolution'];
          this.addAggregation(aggregation);

          this.addPostAggregation({
            name: apply.name,
            type: apply.aggregate,
            fieldName: histogramAggregationName
          });
        } else {
          var applyFilter = apply.filter;
          if (applyFilter) applyFilter = applyFilter.simplify();
          if (this.canUseNativeAggregateFilter(applyFilter)) {
            var aggregation: Druid.Aggregation = {
              name: apply.name,
              type: apply.aggregate === "sum" ? "doubleSum" : apply.aggregate
            };
            if (apply.aggregate !== "count") {
              aggregation.fieldName = apply.attribute;
            }
            if (apply.filter) {
              aggregation = {
                type: "filtered",
                name: apply.name,
                filter: this.timelessFilterToDruid(applyFilter),
                aggregator: aggregation
              };
            }
            this.addAggregation(aggregation);
          } else {
            var jsFilterNamespace = this.filterToJS(apply.filter);
            var jsFilter = jsFilterNamespace.jsFilter;
            var namespace = jsFilterNamespace.namespace;
            var fieldNames: string[] = [];
            var varNames: string[] = [];
            for (var fieldName in namespace) {
              fieldNames.push(fieldName);
              varNames.push(namespace[fieldName]);
            }

            var zeroJsArg = aggregateToJS[apply.aggregate];
            var zero = zeroJsArg[0];
            var jsAgg = zeroJsArg[1];

            var jsIf: string;
            if (apply.aggregate === "count") {
              jsIf = "(" + jsFilter + "?1:" + zero + ")";
            } else {
              fieldNames.push(apply.attribute);
              varNames.push("a");
              jsIf = "(" + jsFilter + "?a:" + zero + ")";
            }

            this.addAggregation({
              name: apply.name,
              type: "javascript",
              fieldNames: fieldNames,
              fnAggregate: "function(cur," + (varNames.join(",")) + "){return " + (jsAgg("cur", jsIf)) + ";}",
              fnCombine: "function(pa,pb){return " + (jsAgg("pa", "pb")) + ";}",
              fnReset: "function(){return " + zero + ";}"
            });
          }
        }
        break;

      case "uniqueCount":
        if (!this.approximate) {
          throw new Error("approximate queries not allowed");
        }
        if (apply.filter) {
          throw new Error("filtering uniqueCount unsupported by driver");
        }

        if (attributeMeta.type === "unique") {
          this.addAggregation({
            name: apply.name,
            type: "hyperUnique",
            fieldName: apply.attribute
          });
        } else {
          this.addAggregation({
            name: apply.name,
            type: "cardinality",
            fieldNames: [apply.attribute],
            byRow: true
          });
        }
        break;

      case "quantile":
        if (!this.approximate) {
          throw new Error("approximate queries not allowed");
        }

        var histogramAggregationName = "_hist_" + apply.attribute;
        var aggregation: Druid.Aggregation = {
          name: histogramAggregationName,
          type: "approxHistogramFold",
          fieldName: apply.attribute
        };

        if (options.hasOwnProperty('druidLowerLimit')) aggregation.lowerLimit = options['druidLowerLimit'];
        if (options.hasOwnProperty('druidUpperLimit')) aggregation.upperLimit = options['druidUpperLimit'];
        if (options.hasOwnProperty('druidResolution')) aggregation.resolution = options['druidResolution'];
        this.addAggregation(aggregation);

        this.addPostAggregation({
          name: apply.name,
          type: "quantile",
          fieldName: histogramAggregationName,
          probability: (<QuantileApply>apply).quantile
        });
        break;

      default:
        throw new Error("unsupported aggregate '" + apply.aggregate + "'");
    }

  }

  public addApplies(applies: FacetApply[]) {
    if (applies.length === 0) {
      this.addAggregateApply(new CountApply({ name: "_dummy" }));
    } else {
      var applySimplifier = new ApplySimplifier({
        postProcessorScheme: druidPostProcessorScheme,
        breakToSimple: true,
        breakAverage: true,
        topLevelConstant: "process"
      });
      applySimplifier.addApplies(applies);

      applySimplifier.getSimpleApplies().forEach((apply) => this.addAggregateApply(apply));
      applySimplifier.getPostProcessors().forEach((postAgg) => this.addPostAggregation(postAgg));
    }

    return this;
  }

  public addCombine(combine: FacetCombine) {
    if (!FacetCombine.isFacetCombine(combine)) throw new TypeError('Must be a combine');
    switch (combine.method) {
      case "slice":
        var sort = combine.sort;
        var limit = (<SliceCombine>combine).limit;

        if (this.queryType === "groupBy") {
          if (sort && (limit != null)) {
            if (!this.approximate) {
              throw new Error("can not sort and limit on without approximate");
            }
            this.queryType = "topN";
            this.threshold = limit;

            if (this.getAttributeMeta(this.dimension.dimension).type === "large") {
              this.context.doAggregateTopNMetricFirst = true;
            }

            if (sort.prop === this.dimension.outputName) {
              if (sort.direction === "ascending") {
                this.metric = {
                  type: "lexicographic"
                };
              } else {
                this.metric = {
                  type: "inverted",
                  metric: {
                    type: "lexicographic"
                  }
                };
              }
            } else {
              if (sort.direction === "descending") {
                this.metric = sort.prop;
              } else {
                this.metric = {
                  type: "inverted",
                  metric: sort.prop
                };
              }
            }
          } else if (sort) {
            if (sort.prop !== this.dimension.outputName) {
              throw new Error("can not do an unlimited sort on an apply");
            }
          } else if (limit != null) {
            throw new Error("handle this better");
          }
        }
        break;
      case "matrix":
        sort = combine.sort;
        if (sort) {
          if (sort.direction === "descending") {
            this.metric = sort.prop;
          } else {
            throw new Error("not supported yet");
          }
        }

        var limits = (<MatrixCombine>combine).limits;
        if (limits) {
          var dimensions = this.dimensions;
          for (var i = 0; i < dimensions.length; i++) {
            var dim = dimensions[i];
            if (limits[i] != null) {
              dim.threshold = limits[i];
            }
          }
        }
        break;
      default:
        throw new Error("unsupported method '" + combine.method + "'");
    }

    return this;
  }

  public hasContext(): boolean {
    return Boolean(Object.keys(this.context).length);
  }

  public getQuery(): Druid.Query {
    var query: Druid.Query = {
      queryType: this.queryType,
      dataSource: this.dataSource,
      granularity: this.granularity,
      intervals: this.intervals
    };

    if (this.hasContext()) {
      query.context = this.context;
    }
    if (this.filter) {
      query.filter = this.filter;
    }

    if (this.dimension) {
      if (this.queryType === "groupBy") {
        query.dimensions = [this.dimension];
      } else {
        query.dimension = this.dimension;
      }
    } else if (this.dimensions) {
      query.dimensions = this.dimensions;
    }

    if (this.aggregations.length) {
      query.aggregations = this.aggregations;
    }
    if (this.postAggregations.length) {
      query.postAggregations = this.postAggregations;
    }
    if (this.metric) {
      query.metric = this.metric;
    }
    if (this.threshold) {
      query.threshold = this.threshold;
    }
    return query;
  }
}

DruidQueryBuilder.queryFns = {
  all: (parameters, callback) => {
    var requester = parameters.requester;
    var queryBuilder = parameters.queryBuilder;
    var filter = parameters.filter;
    var condensedCommand = parameters.condensedCommand;
    try {
      queryBuilder.addFilter(filter).addApplies(condensedCommand.applies);

      var queryObj = queryBuilder.getQuery()
    } catch (error) {
      callback(error);
      return;
    }
    requester({
      query: queryObj
    }, (err, ds) => {
      if (err) {
        callback(err);
        return;
      }

      if (!correctSingletonDruidResult(ds)) {
        err = new Error("unexpected result from Druid (all)");
        (<any>err).result = ds; // ToDo: special error type
        callback(err);
        return;
      }

      if (emptySingletonDruidResult(ds)) {
        callback(null, [condensedCommand.getZeroProp()]);
      } else {
        var result: any = ds[0].result;
        if (Array.isArray(result) && !result.length) result = null;
        callback(null, [result || condensedCommand.getZeroProp()]);
      }

    });
  },
  timeBoundary: (parameters, callback) => {
    var requester = parameters.requester;
    var queryBuilder = parameters.queryBuilder;
    var filter = parameters.filter;
    var condensedCommand = parameters.condensedCommand;
    var applies = condensedCommand.applies;
    if (!applies.every((apply) => {
      var aggregate = apply.aggregate;
      return apply.attribute === queryBuilder.timeAttribute && (aggregate === "min" || aggregate === "max");
    })) {
      callback(new Error("can not mix and match min / max time with other aggregates (for now)"));
      return;
    }

    var queryObj: Druid.Query = {
      queryType: "timeBoundary",
      dataSource: queryBuilder.dataSource
    };

    if (queryBuilder.hasContext()) {
      queryObj.context = queryBuilder.context;
    }

    var maxTimeOnly = applies.length === 1 && applies[0].aggregate === "max";
    if (maxTimeOnly) {
      queryObj.queryType = "maxTime";
    }

    requester({
      query: queryObj
    }, (err, ds) => {
      if (err) {
        callback(err);
        return;
      }

      if (!correctSingletonDruidResult(ds) || ds.length !== 1) {
        err = new Error("unexpected result from Druid (" + queryObj.queryType + ")");
        (<any>err).result = ds;
        callback(err);
        return;
      }

      var result = ds[0].result;
      var prop: Prop = {};
      for (var i = 0; i < applies.length; i++) {
        var apply = applies[i];
        var name = apply.name;
        var aggregate = apply.aggregate;
        prop[name] = <any>(new Date(maxTimeOnly ? result : result[aggregate + "Time"]));
      }

      callback(null, [prop]);
    });

  },
  timeseries: (parameters, callback) => {
    var requester = parameters.requester;
    var queryBuilder = parameters.queryBuilder;
    var filter = parameters.filter;
    var condensedCommand = parameters.condensedCommand;

    try {
      queryBuilder.addFilter(filter).addSplit(condensedCommand.split).addApplies(condensedCommand.applies);

      var queryObj = queryBuilder.getQuery()
    } catch (error) {
      callback(error);
      return;
    }

    requester({
      query: queryObj
    }, (err, ds) => {
      if (err) {
        callback(err);
        return;
      }

      if (!Array.isArray(ds)) {
        err = new Error("unexpected result from Druid (timeseries)");
        (<any>err).result = ds;
        callback(err);
        return;
      }

      var split = <TimePeriodSplit>(condensedCommand.split);
      var timePropName = split.name;

      var timezone = split.timezone;
      var splitDuration = split.period;
      var canonicalDurationLengthAndThenSome = splitDuration.canonicalLength() * 1.5;
      var props = ds.map((d: any, i: number) => {
        var rangeStart = new Date(d.timestamp);
        var next = ds[i + 1];
        if (next) {
          next = new Date(next.timestamp);
        }

        var rangeEnd = (next && rangeStart.valueOf() < next.valueOf() && next.valueOf() - rangeStart.valueOf() < canonicalDurationLengthAndThenSome) ?
                        next : splitDuration.move(rangeStart, timezone, 1);

        var prop = d.result;
        prop[timePropName] = [rangeStart, rangeEnd];
        return prop;
      });

      var combine = <SliceCombine>(condensedCommand.getCombine());
      if (combine.sort) {
        if (combine.sort.prop === timePropName) {
          if (combine.sort.direction === "descending") {
            props.reverse();
          }
        } else {
          props.sort(combine.sort.getCompareFn());
        }
      }

      if (combine.limit != null) {
        var limit = combine.limit;
        driverUtil.inPlaceTrim(props, limit);
      }

      callback(null, props);
    });
  },
  topN: (parameters, callback) => {
    var requester = parameters.requester;
    var queryBuilder = parameters.queryBuilder;
    var filter = parameters.filter;
    var condensedCommand = parameters.condensedCommand;

    var split = condensedCommand.getSplit();
    try {
      queryBuilder
        .addFilter(filter)
        .addSplit(split)
        .addApplies(condensedCommand.applies)
        .addCombine(condensedCommand.getCombine());

      var queryObj = queryBuilder.getQuery()
    } catch (error) {
      callback(error);
      return;
    }

    requester({
      query: queryObj
    }, (err, ds) => {
      if (err) {
        callback(err);
        return;
      }

      if (!correctSingletonDruidResult(ds)) {
        err = new Error("unexpected result from Druid (topN)");
        (<any>err).result = ds;
        callback(err);
        return;
      }

      ds = emptySingletonDruidResult(ds) ? [] : ds[0].result;

      var attributeMeta = queryBuilder.getAttributeMeta(split.attribute);
      if (attributeMeta.type === "range") {
        var splitProp = split.name;
        var rangeSize = (<RangeAttributeMeta>attributeMeta).rangeSize;
        ds.forEach((d: any) => {
          if (String(d[splitProp]) === "null") {
            return d[splitProp] = null;
          } else {
            var start = Number(d[splitProp]);
            return d[splitProp] = [start, driverUtil.safeAdd(start, rangeSize)];
          }
        });
      } else if (split.bucket === "continuous") {
        splitProp = split.name;
        var splitSize = (<ContinuousSplit>split).size;
        ds.forEach((d: any) => {
          if (String(d[splitProp])  === "null") {
            return d[splitProp] = null;
          } else {
            var start = Number(d[splitProp]);
            return d[splitProp] = [start, driverUtil.safeAdd(start, splitSize)];
          }
        });
      }

      callback(null, ds);
    });
  },
  allData: (parameters, callback) => {
    var requester = parameters.requester;
    var queryBuilder = parameters.queryBuilder;
    var filter = parameters.filter;
    var condensedCommand = parameters.condensedCommand;
    var allDataChunks = DruidQueryBuilder.ALL_DATA_CHUNKS;

    var combine = condensedCommand.getCombine()
    try {
      queryBuilder
        .addFilter(filter)
        .addSplit(condensedCommand.split)
        .addApplies(condensedCommand.applies)
        .addCombine(SliceCombine.fromJS({
          sort: {
            compare: "natural",
            prop: condensedCommand.split.name,
            direction: combine.sort.direction || "ascending"
          },
          limit: allDataChunks
        }));

      var queryObj = queryBuilder.getQuery()
    } catch (error) {
      callback(error);
      return;
    }

    var props: Prop[] = [];
    var done = false;
    queryObj.metric.previousStop = null;
    async.whilst(() => !done, (callback: (error?: Error) => void) => {
      requester({
        query: queryObj
      }, (err, ds) => {
        if (err) {
          callback(err);
          return;
        }

        if (!correctSingletonDruidResult(ds)) {
          err = new Error("unexpected result from Druid (topN/allData)");
          (<any>err).result = ds;
          callback(err);
          return;
        }

        var myProps = emptySingletonDruidResult(ds) ? [] : ds[0].result;
        props = props.concat(myProps);
        if (myProps.length < allDataChunks) {
          done = true;
        } else {
          queryObj.metric.previousStop = myProps[allDataChunks - 1][condensedCommand.split.name];
        }
        return callback();
      });
    }, (err: Error) => {
      if (err) {
        callback(err);
        return;
      }

      callback(null, props.length ? props : null);
    });
  },
  groupBy: (parameters, callback) => {
    var requester = parameters.requester;
    var queryBuilder = parameters.queryBuilder;
    var filter = parameters.filter;
    var condensedCommand = parameters.condensedCommand;

    try {
      queryBuilder
        .addFilter(filter)
        .addSplit(condensedCommand.split)
        .addApplies(condensedCommand.applies)
        .addCombine(condensedCommand.getCombine());

      var queryObj = queryBuilder.getQuery()
    } catch (error) {
      callback(error);
      return;
    }

    requester({
      query: queryObj
    }, (err, ds) => {
      if (err) {
        callback(err);
        return;
      }

      callback(null, ds.map((d: any) => d.event));
    });
  },
  histogram: (parameters, callback) => {
    var requester = parameters.requester;
    var queryBuilder = parameters.queryBuilder;
    var filter = parameters.filter;
    var condensedCommand = parameters.condensedCommand;
    if (!condensedCommand.applies.every((apply) => apply.aggregate === "count")) {
      callback(new Error("only count aggregated applies are supported"));
      return;
    }

    try {
      queryBuilder
        .addFilter(filter)
        .addSplit(condensedCommand.split);

      var queryObj = queryBuilder.getQuery()
    } catch (error) {
      callback(error);
      return;
    }

    requester({
      query: queryObj
    }, (err, ds) => {
      if (err) {
        callback(err);
        return;
      }

      if (!correctSingletonDruidResult(ds)) {
        err = new Error("unexpected result from Druid (histogram)");
        (<any>err).result = ds;
        callback(err);
        return;
      }

      if (emptySingletonDruidResult(ds)) {
        callback(null, null);
        return;
      }

      if (!ds[0].result || !ds[0].result.histogram) {
        callback(new Error("invalid histogram result"), null);
        return;
      }

      var histData = ds[0].result.histogram;
      var breaks = histData.breaks;
      var counts = histData.counts;
      var histName = condensedCommand.split.name;
      var countName = condensedCommand.applies[0].name;

      var props: Prop[] = [];
      for (var i = 0; i < counts.length; i++) {
        var count = counts[i];
        if (count === 0) continue;
        var range = [breaks[i], breaks[i + 1]];
        var prop: Prop = {};
        prop[histName] = <any>range;
        prop[countName] = count;
        props.push(prop);
      }

      var combine = <SliceCombine>(condensedCommand.getCombine());
      if (combine.sort) {
        if (combine.sort.prop === histName) {
          if (combine.sort.direction === "descending") {
            props.reverse();
          }
        } else {
          props.sort(combine.sort.getCompareFn());
        }
      }

      if (combine.limit != null) {
        driverUtil.inPlaceTrim(props, combine.limit);
      }

      callback(null, props);
    });
  },
  heatmap: (parameters, callback) => {
    var requester = parameters.requester;
    var queryBuilder = parameters.queryBuilder;
    var filter = parameters.filter;
    var parentSegment = parameters.parentSegment;
    var condensedCommand = parameters.condensedCommand;

    try {
      queryBuilder
        .addFilter(filter)
        .addSplit(condensedCommand.split)
        .addApplies(condensedCommand.applies)
        .addCombine(condensedCommand.getCombine());

      var queryObj = queryBuilder.getQuery()
    } catch (error) {
      callback(error);
      return;
    }

    requester({
      query: queryObj
    }, (err, ds) => {
      if (err) {
        callback(err);
        return;
      }

      if (!correctSingletonDruidResult(ds)) {
        err = new Error("unexpected result from Druid (heatmap)");
        (<any>err).result = ds;
        callback(err);
        return;
      }

      if (emptySingletonDruidResult(ds)) {
        callback(null, null);
        return;
      }

      var dimensionRenameNeeded = false;
      var dimensionRenameMap: Lookup<string> = {};
      var splits = (<TupleSplit>(condensedCommand.split)).splits;
      for (var i = 0; i < splits.length; i++) {
        var split = splits[i];
        if (split.name === split.attribute) continue;
        dimensionRenameMap[split.attribute] = split.name;
        dimensionRenameNeeded = true;
      }

      var props = ds[0].result;

      if (dimensionRenameNeeded) {
        props.forEach((prop: Prop) => {
          for (var v = 0; v < props.length; v++) {
            var k = props[v];
            var renameTo = dimensionRenameMap[k];
            if (renameTo) {
              props[renameTo] = v;
            }
          }
        });
      }

      callback(null, props);
    });
  }
};

interface DatasetInfo {
  dataset: string;
  condensedCommand: CondensedCommand;
  driven?: boolean;
}

function splitUpCondensedCommand(condensedCommand: CondensedCommand) {
  var datasets = condensedCommand.getDatasets();
  var combine = condensedCommand.getCombine();

  var perDatasetInfo: DatasetInfo[] = [];
  if (datasets.length <= 1) {
    if (datasets.length) {
      perDatasetInfo.push({
        dataset: datasets[0],
        condensedCommand: condensedCommand
      });
    }

    return {
      postProcessors: [],
      perDatasetInfo: perDatasetInfo
    };
  }
  for (var i = 0; i < datasets.length; i++) {
    var dataset = datasets[i];
    var datasetSplit: FacetSplit = null;
    if (condensedCommand.split) {
      var splitName = condensedCommand.split.name;
      var _ref2 = (<ParallelSplit>condensedCommand.split).splits;
      for (var j = 0; j < _ref2.length; j++) {
        var subSplit = _ref2[j];
        if (subSplit.getDataset() !== dataset) {
          continue;
        }
        datasetSplit = subSplit.addName(splitName);
        break;
      }
    }

    var datasetCondensedCommand = new CondensedCommand();
    if (datasetSplit) {
      datasetCondensedCommand.setSplit(datasetSplit);
    }
    perDatasetInfo.push({
      dataset: dataset,
      condensedCommand: datasetCondensedCommand
    });
  }
  var applySimplifier = new ApplySimplifier({
    postProcessorScheme: ApplySimplifier.JS_POST_PROCESSOR_SCHEME
  });
  applySimplifier.addApplies(condensedCommand.applies);

  var appliesByDataset = applySimplifier.getSimpleAppliesByDataset();
  var sortApplyComponents = applySimplifier.getApplyComponents(combine && combine.sort ? combine.sort.prop : null);

  perDatasetInfo.forEach((info) => {
    var applies = appliesByDataset[info.dataset] || [];
    return applies.map((apply) => info.condensedCommand.addApply(apply));
  });
  if (combine) {
    var sort = combine.sort;
    if (sort) {
      splitName = condensedCommand.split.name;
      if (sortApplyComponents.length === 0) {
        perDatasetInfo.forEach((info) => info.condensedCommand.setCombine(combine));
      } else if (sortApplyComponents.length === 1) {
        var mainDataset = sortApplyComponents[0].getDataset();

        perDatasetInfo.forEach((info) => {
          if (info.dataset === mainDataset) {
            return info.condensedCommand.setCombine(combine);
          } else {
            info.driven = true;
            return info.condensedCommand.setCombine(SliceCombine.fromJS({
              sort: {
                compare: "natural",
                direction: "descending",
                prop: splitName
              },
              limit: (<SliceCombine>combine).limit
            }));
          }
        });
      } else {
        perDatasetInfo.forEach((info) => {
          var infoApply = driverUtil.find(sortApplyComponents, (apply) => apply.getDataset() === info.dataset);
          if (infoApply) {
            var sortProp = infoApply.name
          } else {
            sortProp = splitName;
            info.driven = true;
          }

          return info.condensedCommand.setCombine(SliceCombine.fromJS({
            sort: {
              compare: "natural",
              direction: "descending",
              prop: sortProp
            },
            limit: 1000
          }));
        });
      }
    } else {
      null;
    }
  } else {
    null;
  }

  return {
    postProcessors: applySimplifier.getPostProcessors(),
    perDatasetInfo: perDatasetInfo
  };
}

interface MultiDatasetQueryParameters {
  requester: Requester.FacetRequester<Druid.Query>;
  builderSettings: DruidQueryBuilderParameters;
  parentSegment: SegmentTree;
  condensedCommand: CondensedCommand;
}

function multiDatasetQuery(parameters: MultiDatasetQueryParameters, callback: QueryFunctionCallback): void {
  var requester = parameters.requester;
  var parentSegment = parameters.parentSegment;
  var condensedCommand = parameters.condensedCommand;
  var builderSettings = parameters.builderSettings;

  var datasets = condensedCommand.getDatasets();
  var split = condensedCommand.getSplit();
  var combine = condensedCommand.getCombine();

  if (datasets.length === 0) {
    callback(null, [{}]);
    return;
  }

  if (datasets.length === 1) {
    DruidQueryBuilder.makeSingleQuery({
      parentSegment: parentSegment,
      filter: parentSegment.meta['filtersByDataset'][datasets[0]],
      condensedCommand: condensedCommand,
      queryBuilder: new DruidQueryBuilder(builderSettings),
      requester: requester
    }, callback);
    return;
  }

  var splitUp = splitUpCondensedCommand(condensedCommand);
  var postProcessors = splitUp.postProcessors;
  var perDatasetInfo = splitUp.perDatasetInfo;

  function performApplyCombine(result: Prop[]): void {
    postProcessors.forEach((postProcessor) => result.forEach(postProcessor));

    if (combine) {
      if (combine.sort) {
        result.sort(combine.sort.getCompareFn());
      }

      var limit = (<SliceCombine>combine).limit;
      if (limit != null) {
        driverUtil.inPlaceTrim(result, limit);
      }
    }
  }

  var hasDriven = false;
  var allApplyNames: string[] = [];
  perDatasetInfo.forEach((info) => {
    hasDriven || (hasDriven = info.driven);
    return info.condensedCommand.applies.map((apply) => allApplyNames.push(apply.name));
  });

  var driverQueries = driverUtil.filterMap(perDatasetInfo, (info) => {
    if (info.driven) {
      return;
    }
    return (callback: QueryFunctionCallback) => DruidQueryBuilder.makeSingleQuery({
      parentSegment: parentSegment,
      filter: parentSegment.meta['filtersByDataset'][info.dataset],
      condensedCommand: info.condensedCommand,
      queryBuilder: new DruidQueryBuilder(builderSettings),
      requester: requester
    }, callback);
  });

  async.parallel(driverQueries, (err: Error, driverResults: Prop[][]) => {
    if (err) {
      callback(err);
      return;
    }

    var driverResult = driverUtil.joinResults(split ? [split.name] : [], allApplyNames, driverResults);

    if (hasDriven && split) {
      var splitName = split.name;

      var drivenQueries = driverUtil.filterMap(perDatasetInfo, (info) => {
        if (!info.driven) {
          return;
        }

        if (info.condensedCommand.split.bucket !== "identity") {
          throw new Error("This (" + split.bucket + ") split not implemented yet");
        }
        var driverFilter = new InFilter({
          attribute: info.condensedCommand.split.attribute,
          values: <any>(driverResult.map((prop) => prop[splitName]))
        });

        return (callback: QueryFunctionCallback) => DruidQueryBuilder.makeSingleQuery({
          parentSegment: parentSegment,
          filter: new AndFilter([parentSegment.meta['filtersByDataset'][info.dataset], driverFilter]),
          condensedCommand: info.condensedCommand,
          queryBuilder: new DruidQueryBuilder(builderSettings),
          requester: requester
        }, callback);
      });

      async.parallel(drivenQueries, (err: Error, drivenResults: Prop[][]) => {
        var fullResult = driverUtil.joinResults([splitName], allApplyNames, [driverResult].concat(drivenResults));
        performApplyCombine(fullResult);
        callback(null, fullResult);
      });
    } else {
      performApplyCombine(driverResult);
      callback(null, driverResult);
    }
  });

}

export interface DruidDriverParameters {
  requester: Requester.FacetRequester<Druid.Query>;
  dataSource: any; // ToDo: string | string[]
  timeAttribute: string;
  attributeMetas: Lookup<AttributeMeta>;
  forceInterval: boolean;
  approximate: boolean;
  filter: FacetFilter;
  concurrentQueryLimit: number;
  queryLimit: number;
}

interface Callback {
  (error?: Error, result?: any): void
}

export function druidDriver(parameters: DruidDriverParameters) {
  var requester = parameters.requester;
  var dataSource = parameters.dataSource;
  var timeAttribute = parameters.timeAttribute || "timestamp";
  var attributeMetas = parameters.attributeMetas || {};
  var approximate = Boolean(parameters.approximate);
  var filter = parameters.filter;
  var forceInterval = parameters.forceInterval;
  var concurrentQueryLimit = parameters.concurrentQueryLimit || 16;
  var queryLimit = parameters.queryLimit || Infinity;

  if (typeof requester !== "function") {
    throw new Error("must have a requester");
  }

  for (var k in attributeMetas) {
    if (!AttributeMeta.isAttributeMeta(attributeMetas[k])) {
      throw new TypeError("`attributeMeta` for attribute '" + k + "' must be an AttributeMeta");
    }
  }

  var queriesMade = 0;
  var driver: any = (request: Driver.Request, callback: Driver.DataCallback) => {
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

    var init = true;
    var rootSegment = new SegmentTree({
      prop: {}
    }, { filtersByDataset: query.getFiltersByDataset(filter) });

    var segments = [rootSegment];

    var condensedGroups = query.getCondensedCommands();

    function queryDruid(condensedCommand: CondensedCommand, lastCmd: boolean, callback: Callback) {
      if (condensedCommand.split && condensedCommand.split.segmentFilter) {
        var segmentFilterFn = condensedCommand.split.segmentFilter.getFilterFn();
        driverUtil.inPlaceFilter(segments, segmentFilterFn);
      }
      async.mapLimit(
        segments,
        concurrentQueryLimit,
        (parentSegment: SegmentTree, callback: (err: Error, splits?: SegmentTree[]) => void) => {
          queriesMade++;
          if (queryLimit < queriesMade) {
            var err = new Error("query limit exceeded");
            (<any>err).limit = queryLimit;
            callback(err);
            return;
          }

          multiDatasetQuery({
            requester: requester,
            builderSettings: {
              dataSource: dataSource,
              timeAttribute: timeAttribute,
              attributeMetas: attributeMetas,
              forceInterval: forceInterval,
              approximate: approximate,
              context: context
            },
            parentSegment: parentSegment,
            condensedCommand: condensedCommand
          }, (err, props) => {
            if (err) {
              callback(err);
              return;
            }

            if (props === null) {
              callback(null, null);
              return;
            }

            if (condensedCommand.split) {
              var propToSplit: (prop: Prop) => SegmentTree = lastCmd ?
                (prop) => {
                  return new SegmentTree({ prop: prop });
                } :
                (prop) => {
                  return new SegmentTree({
                    prop: prop
                  }, {
                    filtersByDataset: FacetFilter.andFiltersByDataset(
                      parentSegment.meta['filtersByDataset'],
                      condensedCommand.split.getFilterByDatasetFor(prop)
                    )
                  });
                };

              parentSegment.setSplits(props.map(propToSplit));
            } else {
              var newSegmentTree = new SegmentTree({
                prop: props[0]
              }, {
                filtersByDataset: parentSegment.meta['filtersByDataset']
              })
              parentSegment.setSplits([newSegmentTree]);
            }

            callback(null, parentSegment.splits);
          });
        },
        (err: Error, results: SegmentTree[][]) => {
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
        }
      );
    }

    var cmdIndex = 0
    async.whilst(
      () => cmdIndex < condensedGroups.length && rootSegment,
      (callback: Callback) => {
        var condensedGroup = condensedGroups[cmdIndex];
        cmdIndex++;
        var last = cmdIndex === condensedGroups.length;
        queryDruid(condensedGroup, last, callback);
      },
      (err: Error) => {
        if (err) {
          callback(err);
          return;
        }

        callback(null, (rootSegment || new SegmentTree({})).selfClean());
      }
    );
  }

  driver.introspect = (opts: any, callback: Driver.IntrospectionCallback) => {
    requester({
      query: {
        queryType: "introspect",
        dataSource: Array.isArray(dataSource) ? dataSource[0] : dataSource
      }
    }, (err: Error, ret: Druid.IntrospectResult) => {
      if (err) {
        callback(err);
        return;
      }

      var attributes: Driver.AttributeIntrospect[] = [{
        name: timeAttribute,
        time: true
      }];

      ret.dimensions
        .sort()
        .forEach((dimension) => {
          attributes.push({
            name: dimension,
            categorical: true
          })
        });

      var metrics = ret.metrics.sort();
      for (var i = 0; i < metrics.length; i++) {
        var metric = metrics[i];
        if (metric.indexOf("_hist") !== -1 || metric.indexOf("unique_") === 0) {
          continue;
        }
        attributes.push({
          name: metric,
          numeric: true
        });
      }

      callback(null, attributes);
    });
  };

  return driver;
}
