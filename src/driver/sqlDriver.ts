/// <reference path="../../typings/async/async.d.ts" />
/// <reference path="../../definitions/mysql.d.ts" />
"use strict";

import Basics = require("../basics") // Prop up
import Lookup = Basics.Lookup;

import async = require("async");

import HigherObjectModule = require("higher-object");
import isInstanceOf = HigherObjectModule.isInstanceOf;

import chronology = require("chronology");
import Duration = chronology.Duration;

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
import ConstantApply = FacetApplyModule.ConstantApply;
import CountApply = FacetApplyModule.CountApply;
import SumApply = FacetApplyModule.SumApply;
import AverageApply = FacetApplyModule.AverageApply;
import MinApply = FacetApplyModule.MinApply;
import MaxApply = FacetApplyModule.MaxApply;
import UniqueCountApply = FacetApplyModule.UniqueCountApply;
import QuantileApply = FacetApplyModule.QuantileApply;

import FacetSortModule = require("../query/sort");
import FacetSort = FacetSortModule.FacetSort;

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

interface SqlAggFn {
  (column: string): string;
}

var aggregateToSqlFn: Lookup<SqlAggFn> = {
  count: (c) => "COUNT(" + c + ")",
  sum: (c) => "SUM(" + c + ")",
  average: (c) => "AVG(" + c + ")",
  min: (c) => "MIN(" + c + ")",
  max: (c) => "MAX(" + c + ")",
  uniqueCount: (c) => "COUNT(DISTINCT " + c + ")"
};

var aggregateToZero: Lookup<string> = {
  count: "NULL",
  sum: "0",
  average: "NULL",
  min: "NULL",
  max: "NULL",
  uniqueCount: "NULL"
};

var arithmeticToSqlOp: Lookup<string> = {
  add: "+",
  subtract: "-",
  multiply: "*",
  divide: "/"
};

var directionMap: Lookup<string> = {
  ascending: "ASC",
  descending: "DESC"
};

interface TimeBucketing {
  select: string;
  group: string;
}

var timeBucketing: Lookup<TimeBucketing> = {
  "PT1S": {
    select: "%Y-%m-%dT%H:%i:%SZ",
    group: "%Y-%m-%dT%H:%i:%SZ"
  },
  "PT1M": {
    select: "%Y-%m-%dT%H:%i:00Z",
    group: "%Y-%m-%dT%H:%i"
  },
  "PT1H": {
    select: "%Y-%m-%dT%H:00:00Z",
    group: "%Y-%m-%dT%H"
  },
  "P1D": {
    select: "%Y-%m-%dT00:00:00Z",
    group: "%Y-%m-%d"
  },
  "P1W": {
    select: "%Y-%m-%dT00:00:00Z",
    group: "%Y-%m/%u"
  },
  "P1M": {
    select: "%Y-%m-00T00:00:00Z",
    group: "%Y-%m"
  },
  "P1Y": {
    select: "%Y-00-00T00:00:00Z",
    group: "%Y"
  }
};

export interface DatasetPart {
  splitSelectParts: string[];
  applySelectParts: string[];
  fromWherePart: string;
  groupByParts: string[];
}

export interface SQLQueryBuilderParameters {
  datasetToTable: Lookup<string>;
}

export class SQLQueryBuilder {
  public commonSplitSelectParts: string[] = [];
  public commonApplySelectParts: string[] = [];
  public datasets: string[] = [];
  public datasetParts: Lookup<DatasetPart>;
  public orderByPart: string;
  public limitPart: string;

  constructor(parameters: SQLQueryBuilderParameters) {
    var datasetToTable = parameters.datasetToTable;
    if (typeof datasetToTable !== "object") {
      throw new Error("must have datasetToTable mapping");
    }

    this.datasetParts = {};
    for (var dataset in datasetToTable) {
      var table = datasetToTable[dataset];
      this.datasets.push(dataset);
      this.datasetParts[dataset] = {
        splitSelectParts: [],
        applySelectParts: [],
        fromWherePart: this.escapeAttribute(table),
        groupByParts: []
      };
    }

    this.orderByPart = null;
    this.limitPart = null;
  }

  public escapeAttribute(attribute: any): string {
    if (isNaN(attribute)) {
      return "`" + attribute + "`";
    } else {
      return String(attribute);
    }
  }

  public escapeValue(value: string): string {
    return '"' + value + '"';
  }

  public dateToSQL(date: Date): string {
    return date.toISOString()
               .replace("T", " ")
               .replace(/\.\d\d\dZ$/, "")
               .replace(" 00:00:00", "");
  }

  public filterToSQL(filter: FacetFilter): string {
    switch (filter.type) {
      case "true":
        return "1 = 1";
      case "false":
        return "1 = 2";
      case "is":
        return (this.escapeAttribute(filter.attribute)) + " = " + (this.escapeValue((<IsFilter>filter).value));
      case "in":
        return (this.escapeAttribute(filter.attribute)) + " IN (" + ((<InFilter>filter).values.map(this.escapeValue, this).join(",")) + ")";
      case "contains":
        return (this.escapeAttribute(filter.attribute)) + " LIKE \"%" + (<ContainsFilter>filter).value + "%\"";
      case "match":
        return (this.escapeAttribute(filter.attribute)) + " REGEXP '" + (<MatchFilter>filter).expression + "'";
      case "within":
        var attribute = this.escapeAttribute(filter.attribute);
        var range = (<WithinFilter>filter).range;
        var r0 = range[0];
        var r1 = range[1];
        if (isInstanceOf(r0, Date) && isInstanceOf(r1, Date)) {
          return "'" + (this.dateToSQL(r0)) + "' <= " + attribute + " AND " + attribute + " < '" + (this.dateToSQL(r1)) + "'";
        } else {
          return r0 + " <= " + attribute + " AND " + attribute + " < " + r1;
        }
        break;
      case "not":
        return "NOT (" + (this.filterToSQL((<NotFilter>filter).filter)) + ")";
      case "and":
        return "(" + (<AndFilter>filter).filters.map(this.filterToSQL, this).join(") AND (") + ")";
      case "or":
        return "(" + (<OrFilter>filter).filters.map(this.filterToSQL, this).join(") OR (") + ")";
      default:
        throw new Error("filter type '" + filter.type + "' unsupported by driver");
    }
  }

  public addFilters(filtersByDataset: FiltersByDataset) {
    var datasetParts = this.datasetParts;
    for (var dataset in datasetParts) {
      var datasetPart = datasetParts[dataset];
      var filter = filtersByDataset[dataset];
      if (!filter) {
        throw new Error("must have filter for dataset '" + dataset + "'");
      }
      if (filter.type === "true") {
        continue;
      }
      datasetPart.fromWherePart += " WHERE " + (this.filterToSQL(filter));
    }
    return this;
  }

  public splitToSQL(split: FacetSplit, name: string): { selectPart: string; groupByPart: string } {
    switch (split.bucket) {
      case "identity":
        var groupByPart = this.escapeAttribute(split.attribute);
        return {
          selectPart: groupByPart + " AS `" + name + "`",
          groupByPart: groupByPart
        };
      case "continuous":
        groupByPart = driverUtil.continuousFloorExpression(
          this.escapeAttribute(split.attribute),
          "FLOOR",
          (<ContinuousSplit>split).size,
          (<ContinuousSplit>split).offset
        );
        return {
          selectPart: groupByPart + " AS `" + name + "`",
          groupByPart: groupByPart
        };
      case "timePeriod":
        var bucketSpec = timeBucketing[(<TimePeriodSplit>split).period.toString()];
        if (!bucketSpec) {
          throw new Error("unsupported timePeriod period '" + (<TimePeriodSplit>split).period + "'");
        }

        var bucketTimezone = (<TimePeriodSplit>split).timezone;
        if (bucketTimezone.valueOf() === "Etc/UTC") {
          var sqlAttribute = this.escapeAttribute(split.attribute)
        } else {
          sqlAttribute = "CONVERT_TZ(" + (this.escapeAttribute(split.attribute)) + ", '+0:00', " + bucketTimezone + ")";
        }

        return {
          selectPart: "DATE_FORMAT(" + sqlAttribute + ", '" + bucketSpec.select + "') AS `" + name + "`",
          groupByPart: "DATE_FORMAT(" + sqlAttribute + ", '" + bucketSpec.group + "')"
        };
      case "tuple":
        var parts = (<TupleSplit>split).splits.map((split) => this.splitToSQL(split, ''), this);
        return {
          selectPart: parts.map((part) => part.selectPart).join(", "),
          groupByPart: parts.map((part) => part.groupByPart).join(", ")
        };
      default:
        throw new Error("bucket '" + split.bucket + "' unsupported by driver");
    }
  }

  public addSplit(split: FacetSplit) {
    if (!FacetSplit.isFacetSplit(split)) {
      throw new TypeError("split must be a FacetSplit");
    }
    var splits = split.bucket === "parallel" ? (<ParallelSplit>split).splits : [split];
    this.commonSplitSelectParts.push("`" + split.name + "`");
    splits.forEach((subSplit) => {
      var datasetPart = this.datasetParts[subSplit.getDataset()]
      var selectGroup = this.splitToSQL(subSplit, split.name);
      var selectPart = selectGroup.selectPart;
      var groupByPart = selectGroup.groupByPart;
      datasetPart.splitSelectParts.push(selectPart);
      return datasetPart.groupByParts.push(groupByPart);
    });
    return this;
  }

  public applyToSQLExpression(apply: FacetApply) {
    if (apply.aggregate) {
      switch (apply.aggregate) {
        case "constant":
          var applyStr = this.escapeAttribute((<ConstantApply>apply).value);
          break;
        case "count":
        case "sum":
        case "average":
        case "min":
        case "max":
        case "uniqueCount":
          var expression = apply.aggregate === "count" ? "1" : this.escapeAttribute(apply.attribute);
          if (apply.filter) {
            var zero = aggregateToZero[apply.aggregate];
            expression = "IF(" + (this.filterToSQL(apply.filter)) + ", " + expression + ", " + zero + ")";
          }
          applyStr = aggregateToSqlFn[apply.aggregate](expression);
          break;
        case "quantile":
          throw new Error("not implemented yet");
          break;
        default:
          throw new Error("unsupported aggregate '" + apply.aggregate + "'");
      }

      return applyStr;
    }

    var sqlOp = arithmeticToSqlOp[apply.arithmetic];
    if (!sqlOp) {
      throw new Error("unsupported arithmetic '" + apply.arithmetic + "'");
    }
    var operands = apply.operands;
    var op1SQL = this.applyToSQLExpression(operands[0]);
    var op2SQL = this.applyToSQLExpression(operands[1]);
    applyStr = "(" + op1SQL + " " + sqlOp + " " + op2SQL + ")";
    return applyStr;
  }

  public applyToSQL(apply: FacetApply): string {
    return (this.applyToSQLExpression(apply)) + " AS `" + apply.name + "`";
  }

  public addApplies(applies: FacetApply[]): SQLQueryBuilder {
    var sqlProcessorScheme: PostProcessorScheme<string, string> = {
      constant: (apply: ConstantApply) => {
        return String(apply.value);
      },
      getter: (apply: FacetApply) => {
        return apply.name;
      },
      arithmetic: (arithmetic, lhs, rhs) => {
        var sqlOp = arithmeticToSqlOp[arithmetic];
        if (!sqlOp) {
          throw new Error("unknown arithmetic");
        }
        return "(IFNULL(" + lhs + ", 0) " + sqlOp + " IFNULL(" + rhs + ", 0))";
      },
      finish: (name, getter) => getter + " AS `" + name + "`"
    };

    var applySimplifier = new ApplySimplifier({
      postProcessorScheme: sqlProcessorScheme
    });
    applySimplifier.addApplies(applies);

    var appliesByDataset = applySimplifier.getSimpleAppliesByDataset();
    this.commonApplySelectParts = applySimplifier.getPostProcessors();
    for (var dataset in appliesByDataset) {
      var datasetApplies = appliesByDataset[dataset];
      this.datasetParts[dataset].applySelectParts = datasetApplies.map(this.applyToSQL, this);
    }

    return this;
  }

  public addSort(sort: FacetSort) {
    if (!sort) return;
    var sqlDirection = directionMap[sort.direction];
    switch (sort.compare) {
      case "natural":
        this.orderByPart = "ORDER BY " + (this.escapeAttribute(sort.prop));
        return this.orderByPart += " " + sqlDirection;

      case "caseInsensitive":
        throw new Error("not implemented yet (ToDo)");
        break;

      default:
        throw new Error("compare '" + sort.compare + "' unsupported by driver");
    }
  }

  public addCombine(combine: FacetCombine) {
    if (!FacetCombine.isFacetCombine(combine)) {
      throw new TypeError("combine must be a FacetCombine");
    }
    switch (combine.method) {
      case "slice":
        var sort = combine.sort;
        if (sort) {
          this.addSort(sort);
        }

        var limit = (<SliceCombine>combine).limit;
        if (limit != null) {
          this.limitPart = "LIMIT " + limit;
        }
        break;
      case "matrix":
        sort = combine.sort;
        if (sort) {
          this.addSort(sort);
        }
        break;
      default:
        throw new Error("method '" + combine.method + "' unsupported by driver");
    }

    return this;
  }

  public getQueryForDataset(dataset: string, topLevel: boolean = false): string {
    var datasetPart = this.datasetParts[dataset];
    var selectPartsParts: string[][] = [datasetPart.splitSelectParts, datasetPart.applySelectParts];
    if (topLevel) {
      selectPartsParts.push(this.commonApplySelectParts);
    }
    var selectParts = driverUtil.flatten(selectPartsParts);
    if (!selectParts.length) {
      return null;
    }
    var select = selectParts.join(", ");
    var groupBy = datasetPart.groupByParts.join(", ") || '""';
    return "SELECT " + select + " FROM " + datasetPart.fromWherePart + " GROUP BY " + groupBy;
  }

  public getQuery() {
    if (this.datasets.length > 1) {
      var partials = this.datasets.map((function (dataset: string) {
        var selectParts = [].concat(
          this.commonSplitSelectParts.map((commonSplitSelectPart: string) => "`" + dataset + "`." + commonSplitSelectPart),
          this.commonApplySelectParts
        );
        if (!selectParts.length) return null;
        var select = selectParts.join(",\n    ");
        var partialQuery = ["SELECT " + select, "FROM"];
        var innerDataset = dataset;
        var datasetPart = this.datasetParts[innerDataset];
        partialQuery.push("  (" + (this.getQueryForDataset(innerDataset)) + ") AS `" + innerDataset + "`");
        var datasets = this.datasets;
        for (var i = 0; i < datasets.length; i++) {
          innerDataset = datasets[i];
          if (innerDataset === dataset) {
            continue;
          }
          datasetPart = this.datasetParts[innerDataset];
          partialQuery.push("LEFT JOIN");
          partialQuery.push("  (" + (this.getQueryForDataset(innerDataset)) + ") AS `" + innerDataset + "`");
          partialQuery.push("USING(" + (this.commonSplitSelectParts.join(", ")) + ")");
        }

        return "  " + partialQuery.join("\n  ");
      }), this)
      if (!partials.every(Boolean)) {
        return null;
      }
      var query = [partials.join("\nUNION\n")]
    } else {
      var queryForOnlyDataset = this.getQueryForDataset(this.datasets[0], true);
      if (!queryForOnlyDataset) {
        return null;
      }
      query = [queryForOnlyDataset];
    }

    if (this.orderByPart) {
      query.push(this.orderByPart);
    }
    if (this.limitPart) {
      query.push(this.limitPart);
    }
    return query.join("\n") + ";";
  }
}

interface CondensedCommandToSQLParameters {
  requester: Requester.FacetRequester<string>;
  queryBuilder: SQLQueryBuilder;
  parentSegment: SegmentTree;
  condensedCommand: CondensedCommand;
}

interface CondensedCommandToSQLCallback {
  (err: Error, segmentTrees?: SegmentTree[]): void;
}

function condensedCommandToSQL(properties: CondensedCommandToSQLParameters, callback: CondensedCommandToSQLCallback) {
  var requester = properties.requester;
  var queryBuilder = properties.queryBuilder;
  var parentSegment = properties.parentSegment;
  var condensedCommand = properties.condensedCommand;
  var filtersByDataset = parentSegment.meta['filtersByDataset'];

  var split = condensedCommand.getSplit();
  var combine = condensedCommand.getCombine();

  try {
    queryBuilder.addFilters(filtersByDataset);
    if (split) {
      queryBuilder.addSplit(split);
    }
    queryBuilder.addApplies(condensedCommand.applies);
    if (combine) {
      queryBuilder.addCombine(combine);
    }
  } catch (error) {
    callback(error);
    return;
  }

  var queryToRun = queryBuilder.getQuery();
  if (!queryToRun) {
    var newSegmentTree = new SegmentTree({
      prop: {}
    }, {
      filtersByDataset: filtersByDataset
    });
    callback(null, [newSegmentTree]);
    return;
  }

  requester({
    query: queryToRun
  }, (err, ds) => {
    if (err) {
      callback(err);
      return;
    }

    if (split) {
      var splitProp = split.name;

      if (split.bucket === "continuous") {
        var splitSize = (<ContinuousSplit>split).size;
        ds.forEach((d: Lookup<any>) => {
          var start = d[splitProp];
          return d[splitProp] = [start, start + splitSize];
        });
      } else if (split.bucket === "timePeriod") {
        var timezone = (<TimePeriodSplit>split).timezone;
        var splitDuration = (<TimePeriodSplit>split).period;
        ds.forEach((d: Lookup<any>) => {
          var rangeStart = new Date(d[splitProp]);
          var range = [rangeStart, splitDuration.move(rangeStart, timezone, 1)];
          return d[splitProp] = range;
        });
      }

      var splits = ds.map((prop: Lookup<any>) => {
        return new SegmentTree({
          prop: prop
        }, {
          filtersByDataset: FacetFilter.andFiltersByDataset(filtersByDataset, split.getFilterByDatasetFor(prop))
        });
      })
    } else {
      if (ds.length > 1) {
        callback(new Error("unexpected result"));
        return;
      }

      if (ds.length === 0) {
        ds.push(condensedCommand.getZeroProp());
      }

      newSegmentTree = new SegmentTree({
        prop: ds[0]
      }, {
        filtersByDataset: filtersByDataset
      });
      splits = [newSegmentTree];
    }

    callback(null, splits);
  });
}

interface SQLDescribeRow {
  Field: string;
  Type: string;
}

export interface SQLDriverParameters {
  requester: Requester.FacetRequester<string>;
  table: string;
  filter: FacetFilter;
}

export function sqlDriver(parameters: SQLDriverParameters): Driver.FacetDriver {
  var requester = parameters.requester;
  var table = parameters.table;
  var filter = parameters.filter;
  if (typeof requester !== "function") {
    throw new Error("must have a requester");
  }
  if (typeof table !== "string") {
    throw new Error("must have table");
  }

  var driver: any = (request: Driver.Request, callback: Driver.DataCallback) => {
    if (!request) {
      callback(new Error("request not supplied"));
      return;
    }
    // var context = request.context;
    var query = request.query;
    if (!FacetQuery.isFacetQuery(query)) {
      callback(new TypeError("query must be a FacetQuery"));
    }

    var datasetToTable: Lookup<string> = {};
    query.getDatasets().forEach((dataset) => datasetToTable[dataset.name] = table);

    var init = true;
    var rootSegment = new SegmentTree({
      prop: {}
    }, {
      filtersByDataset: query.getFiltersByDataset(filter)
    });

    var segments = [rootSegment];
    var condensedGroups = query.getCondensedCommands();

    function querySQL(condensedCommand: CondensedCommand, callback: (err?: Error) => void) {
      var QUERY_LIMIT = 10;

      if (condensedCommand.split != null ? condensedCommand.split.segmentFilter : void 0) {
        var segmentFilterFn = condensedCommand.split.segmentFilter.getFilterFn();
        driverUtil.inPlaceFilter(segments, segmentFilterFn);
      }

      async.mapLimit(
        segments,
        QUERY_LIMIT,
        (parentSegment: SegmentTree, callback: CondensedCommandToSQLCallback) =>
          condensedCommandToSQL({
            requester: requester,
            queryBuilder: new SQLQueryBuilder({
              datasetToTable: datasetToTable
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
          }),

        (err, results) => {
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
      )
    }

    var cmdIndex = 0;
    async.whilst(
      () => cmdIndex < condensedGroups.length && rootSegment,
      (callback: (err?: Error) => void) => {
        var condensedGroup = condensedGroups[cmdIndex];
        cmdIndex++;
        querySQL(condensedGroup, callback);
      },
      (err: Error) => {
        if (err) {
          callback(err);
          return;
        }
        callback(null, (rootSegment || new SegmentTree({})).selfClean());
      }
    );
  };

  driver.introspect = (opt: any, callback: Driver.IntrospectionCallback) => {
    requester({
      query: "DESCRIBE `" + table + "`"
    }, (err, columns) => {
      if (err) {
        callback(err);
        return;
      }
      var attributes: Driver.AttributeIntrospect[] = columns.map((column: SQLDescribeRow) => {
        var attribute: Driver.AttributeIntrospect = {
          name: column.Field
        };
        var sqlType = column.Type;
        if (sqlType === "datetime") {
          attribute.time = true;
        } else if (sqlType.indexOf("varchar(") === 0) {
          attribute.categorical = true;
        } else if (sqlType.indexOf("int(") === 0 || sqlType.indexOf("bigint(") === 0) {
          attribute.numeric = true;
          attribute.integer = true;
        } else if (sqlType.indexOf("decimal(") === 0) {
          attribute.numeric = true;
        }
        return attribute;
      });

      callback(null, attributes);
    });
  };

  return driver;
}
