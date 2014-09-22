"use strict";

import Basics = require("../basics") // Prop up
import Lookup = Basics.Lookup;

import FacetFilterModule = require("../query/filter")
import FacetFilter = FacetFilterModule.FacetFilter;
import InFilter = FacetFilterModule.InFilter;
import WithinFilter = FacetFilterModule.WithinFilter;
import AndFilter = FacetFilterModule.AndFilter;
import OrFilter = FacetFilterModule.OrFilter;

import FacetSplitModule = require("../query/split");
import FacetSplit = FacetSplitModule.FacetSplit;

import FacetApplyModule = require("../query/apply");
import FacetApply = FacetApplyModule.FacetApply;

import FacetQueryModule = require("../query/query");
import FacetQuery = FacetQueryModule.FacetQuery;

import SegmentTreeModule = require("../query/segmentTree");
import SegmentTree = SegmentTreeModule.SegmentTree;
//import PropValue = SegmentTreeModule.PropValue;
import Prop = SegmentTreeModule.Prop;

export function flatten<T>(xss: T[][]): T[] {
  var flat: T[] = [];
  xss.forEach((xs) => {
    if (!Array.isArray(xs)) {
      throw new TypeError("bad value in list");
    }
    return xs.map((x) => flat.push(x));
  });

  return flat;
}

export function inPlaceTrim<T>(array: T[], n: number): void {
  if (array.length < n) return;
  array.splice(n, array.length - n);
}

export function inPlaceFilter<T>(array: T[], fn: (value: T, index: number, array: T[]) => boolean): void {
  var i = 0;
  while (i < array.length) {
    if (fn.call(array, array[i], i)) {
      i++;
    } else {
      array.splice(i, 1);
    }
  }
}

export function safeAdd(num: number, delta: number) {
  var stringDelta = String(delta);
  var dotIndex = stringDelta.indexOf(".");
  if (dotIndex === -1 || stringDelta.length === 18) {
    return num + delta;
  } else {
    var scale = Math.pow(10, stringDelta.length - dotIndex - 1);
    return (num * scale + delta * scale) / scale;
  }
}

function dateToIntervalPart(date: Date): string {
  return date.toISOString()
             .replace("Z", "")
             .replace(".000", "")
             .replace(/:00$/, "")
             .replace(/:00$/, "")
             .replace(/T00$/, "");
}

export function datesToInterval(start: Date, end: Date): string {
  return dateToIntervalPart(start) + "/" + dateToIntervalPart(end);
}

export function timeFilterToIntervals(filter: FacetFilter, forceInterval: boolean) {
  if (filter.type === "true") {
    if (forceInterval) throw new Error("must have an interval");
    return ["1000-01-01/3000-01-01"];
  }

  var ors = filter.type === "or" ? (<OrFilter>filter).filters : [filter];
  return ors.map((filter) => {
    var type = filter.type;
    if (type !== "within") {
      throw new Error("can only time filter with a 'within' filter");
    }
    var range = (<WithinFilter>filter).range;
    return datesToInterval(range[0], range[1]);
  });
}

export function continuousFloorExpression(variable: string, floorFn: string, size: number, offset: number) {
  var expr = variable;
  if (offset !== 0) {
    expr = expr + " - " + offset;
  }
  if (offset !== 0 && size !== 1) {
    expr = "(" + expr + ")";
  }
  if (size !== 1) {
    expr = expr + " / " + size;
  }
  expr = floorFn + "(" + expr + ")";
  if (size !== 1) {
    expr = expr + " * " + size;
  }
  if (offset !== 0) {
    expr = expr + " + " + offset;
  }
  return expr;
};

export function find<T>(array: T[], fn: (value: T, index: number, array: T[]) => boolean): T {
  for (var i = 0; i < array.length; i++) {
    var a = array[i];
    if (fn.call(array, a, i)) return a;
  }
  return null;
}

export function filterMap<T, K>(array: T[], fn: (value: T, index: number, array: T[]) => K): K[] {
  var ret: K[] = [];
  for (var i = 0; i < array.length; i++) {
    var a = array[i];
    var v = fn.call(array, a, i);
    if (typeof v === "undefined") continue;
    ret.push(v);
  }
  return ret;
}

export function joinRows(rows: Prop[]): Prop {
  var newRow: Prop = {};
  rows.forEach((row) => {
    for (var prop in row) {
      newRow[prop] = row[prop];
    }
  });
  return newRow;
}

export function joinResults(splitNames: string[], applyNames: string[], results: Prop[][]): Prop[] {
  if (results.length <= 1) {
    return results[0];
  }
  if (splitNames.length === 0) {
    return [joinRows(results.map((result) => result[0]))];
  }
  var zeroRow: Prop = {};
  applyNames.forEach((name) => {
    zeroRow[name] = <any>0;
  });
  var mapping: { [key: string]: any } = {};
  for (var i = 0; i < results.length; i++) {
    var result = results[i];
    if (!result) continue;
    result.forEach((row) => {
      var key = splitNames.map((splitName) => row[splitName]).join("]#;{#")
      if (!mapping[key]) {
        mapping[key] = [zeroRow];
      }
      return mapping[key].push(row);
    });
  }

  var joinResult: Prop[] = [];
  for (var key in mapping) {
    var rows = mapping[key];
    joinResult.push(joinRows(rows));
  }
  return joinResult;
};

export function createTabular(root: SegmentTree, order?: string, rangeFn?: Function): Prop[] {
  if (!root) throw new TypeError("must have a tree");
  if (order == null) order = "none";
  if (order !== "prepend" && order !== "append" && order !== "none") {
    throw new TypeError("order must be on of prepend, append, or none");
  }
  if (rangeFn == null) {
    rangeFn = (range: any[]) => range;
  }
  if (!(root != null ? root.prop : void 0)) {
    return [];
  }
  var result: Prop[];
  createTabularHelper(root, order, rangeFn, {}, result = []);
  return result;
}

function createTabularHelper(root: SegmentTree, order: string, rangeFn: Function, context: Prop, result: Prop[]): void {
  var k: string;
  var myProp: Prop = {};
  for (k in context) {
    myProp[k] = context[k];
  }

  var rootProp = root.prop;
  for (k in rootProp) {
    var v = rootProp[k];
    if (Array.isArray(v)) {
      v = rangeFn(v);
    }
    myProp[k] = v;
  }

  if (order === "preorder" || !root.splits) {
    result.push(myProp);
  }

  if (root.splits) {
    root.splits.forEach((split) => createTabularHelper(split, order, rangeFn, myProp, result));
  }

  if (order === "postorder") {
    result.push(myProp);
  }
}

function csvEscape(str: string): string {
  return '"' + str.replace(/"/g, '""') + '"';
}

export interface TranslateFn {
  (columnName: string, datum: any): any; // PropValue): PropValue;
}

export class Table {
  public query: FacetQuery;
  public titleFn: Function;
  public splitColumns: FacetSplit[];
  public applyColumns: FacetApply[];
  public data: Prop[];
  public translateFn: TranslateFn;

  constructor(parameters: { root: SegmentTree; query: FacetQuery }) {
    var root = parameters.root;
    var query = parameters.query;
    if (!FacetQuery.isFacetQuery(query)) {
      throw new TypeError("query must be a FacetQuery");
    }
    this.query = query;
    this.titleFn = (op: any) => op.name;
    this.splitColumns = flatten(query.getSplits().map((split) => [split]));
    this.applyColumns = query.getApplies();
    this.data = createTabular(root);
    this.translateFn = (columnName, datum) => datum;
  }

  public toTabular(separator: string, lineBreak: string, rangeFn: Function) {
    var columnNames: string[] = [];
    var header: string[] = [];
    var column: any;

    var splitColumns = this.splitColumns;
    for (var i = 0; i < splitColumns.length; i++) {
      column = splitColumns[i];
      var columnTitle = this.titleFn(column);
      if (columnTitle == null) {
        continue;
      }
      columnNames.push(column.name);
      header.push(csvEscape(columnTitle));
    }

    var applyColumns = this.applyColumns;
    for (var j = 0; j < applyColumns.length; j++) {
      column = applyColumns[j];
      columnTitle = this.titleFn(column);
      if (columnTitle == null) {
        continue;
      }
      columnNames.push(column.name);
      header.push(csvEscape(columnTitle));
    }

    rangeFn || (rangeFn = (range: any) => {
      if (range[0] instanceof Date) {
        range = range.map((r: Date) => r.toISOString());
      }
      return range.join("-");
    });

    var translate = this.translateFn;
    var lines = [header.join(separator)];
    this.data.forEach((row) => lines.push(columnNames.map((columnName) => {
      var datum: any = row[columnName] || "";
      datum = translate(columnName, datum);
      if (Array.isArray(datum)) {
        datum = rangeFn(datum);
      }
      return csvEscape(String(datum));
    }).join(separator)));

    return lines.join(lineBreak);
  }

  public translate(fn?: TranslateFn) {
    if (arguments.length) {
      this.translateFn = fn;
      return;
    }
    return this.translateFn;
  }

  public columnTitle(v?: Function) {
    if (arguments.length) {
      this.titleFn = v;
      return;
    }
    return this.titleFn;
  }
}
