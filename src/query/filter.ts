/// <reference path="../../typings/tsd.d.ts" />
"use strict";

import Basics = require("../basics") // Prop up
import Lookup = Basics.Lookup;

import HigherObjectModule = require("higher-object");
import isInstanceOf = HigherObjectModule.isInstanceOf;
import ImmutableClass = HigherObjectModule.ImmutableClass;
import ImmutableInstance = HigherObjectModule.ImmutableInstance;

import CommonModule = require("./common");
import specialJoin = CommonModule.specialJoin;
import find = CommonModule.find;
import dummyObject = CommonModule.dummyObject;
import Dummy = CommonModule.Dummy;
import AttributeValue = CommonModule.AttributeValue;

function smaller<T>(a: T, b: T): T {
  return a < b ? a : b;
}

function larger<T>(a: T, b: T): T {
  return a < b ? b : a;
}

function rangesIntersect(range1: any[], range2: any[]) {
  if (range2[1] < range1[0] || range2[0] > range1[1]) {
    return false;
  } else {
    return range1[0] <= range2[1] && range2[0] <= range1[1];
  }
}

function union(...arraySets: any[][]) {
  var ret: any[] = [];
  var seen: any = {};
  for (var i = 0; i < arraySets.length; i++) {
    var arraySet = arraySets[i];
    for (var j = 0; j < arraySet.length; j++) {
      var value = arraySet[j];
      if (seen[value]) continue;
      seen[value] = true;
      ret.push(value);
    }
  }
  return ret;
}

function intersection<T>(set1: T[], set2: T[]): T[] {
  return set1.filter((value) => set2.indexOf(value) !== -1)
}

function compare(a: any, b: any): number {
  if (a < b) return -1;
  if (a > b) return +1;
  return 0;
}

function arrayCompare(arr1: any[], arr2: any[]): number {
  var arr1Length = arr1.length;
  var arr2Length = arr2.length;
  var lengthDiff = arr1Length - arr2Length;
  if (lengthDiff !== 0 || arr1Length === 0) {
    return lengthDiff;
  }
  for (var i = 0; i < arr1Length; i++) {
    var x1 = arr1[i];
    var diff = compare(x1, arr2[i]);
    if (diff !== 0) {
      return diff;
    }
  }

  return 0;
}

interface PrecedenceMap {
  [idx: string]: number
}

var filterSortTypePrecedence: PrecedenceMap = {
  "true": -2,
  "false": -1,
  "within": 0,
  "in": 0,
  "not in": 0,
  "contains": 0,
  "match": 0,
  "not": 1,
  "and": 2,
  "or": 3
};

var filterSortTypeSubPrecedence: PrecedenceMap = {
  "within": 0,
  "in": 1,
  "not in": 2,
  "contains": 3,
  "match": 4
};

export interface FilterFn {
  (row: any): boolean
}

export interface FiltersByDataset {
  [dataset: string]: FacetFilter
}

export interface FilterStringifier {
  stringify: (filter: FacetFilter) => string
}

var defaultStringifier: FilterStringifier = {
  stringify: (filter: FacetFilter): string => {
    switch (filter.type) {
      case "true":
        return "None";
      case "false":
        return "Nothing";
      case "is":
        var isValue = (<IsFilter>filter).value;
        return filter.attribute + " is " + isValue;
      case "in":
        var values = (<InFilter>filter).values.map(String);
        switch (values.length) {
          case 0:
            return "Nothing";
          case 1:
            return filter.attribute + " is " + values[0];
          case 2:
            return filter.attribute + " is either " + values[0] + " or " + values[1];
          default:
            return filter.attribute + " is one of: " + specialJoin(values, ", ", ", or ");
        }
        break;
      case "contains":
        var containsValue = (<ContainsFilter>filter).value;
        return filter.attribute + " contains '" + containsValue + "'";
      case "match":
        var expression = (<MatchFilter>filter).expression;
        return filter.attribute + " matches /" + expression + "/";
      case "within":
        var range = (<WithinFilter>filter).range;
        var r0 = range[0];
        var r1 = range[1];
        if (r0.toISOString) r0 = r0.toISOString();
        if (r1.toISOString) r1 = r1.toISOString();
        return filter.attribute + " is within " + r0 + " and " + r1;
      case "not":
        var notFilter = String((<NotFilter>filter).filter);
        return "not (" + notFilter + ")";
      case "and":
        var andFilters = (<OrFilter>filter).filters.map(String);
        return andFilters.length > 1 ? "(" + andFilters.join(") and (") + ")" : andFilters[0];
      case "or":
        var orFilters = (<OrFilter>filter).filters.map(String);
        return orFilters.length > 1 ? "(" + orFilters.join(") or (") + ")" : orFilters[0];
      default:
        throw new Error("unknown filter type " + filter.type);
    }
  }
};

export interface FacetFilterJS {
  operation?: string
  type?: string
  attribute?: string
  value?: AttributeValue
  values?: AttributeValue[]
  expression?: string
  range?: any[] // ToDo: Date | Number
  filter?: FacetFilterJS
  filters?: FacetFilterJS[]
}

export interface FacetFilterValue {
  type?: string
  attribute?: string
  value?: AttributeValue
  values?: AttributeValue[]
  expression?: string
  range?: any[] // ToDo: Date | Number
  filter?: FacetFilter
  filters?: FacetFilter[]
}

var check: ImmutableClass<FacetFilterValue, FacetFilterJS>;
export class FacetFilter implements ImmutableInstance<FacetFilterValue, FacetFilterJS> {
  static TRUE: TrueFilter;
  static FALSE: FalseFilter;
  static defaultStringifier = defaultStringifier;

  static filterDiff(subFilter: FacetFilter, superFilter: FacetFilter): FacetFilter[] {
    subFilter = subFilter.simplify();
    superFilter = superFilter.simplify();

    var subFilters = subFilter.type === "true" ? [] : subFilter.type === "and" ? (<AndFilter>subFilter).filters : [subFilter];
    var superFilters = superFilter.type === "true" ? [] : superFilter.type === "and" ? (<AndFilter>superFilter).filters : [superFilter];

    function filterInSuperFilter(filter: FacetFilter): boolean {
      for (var i = 0; i < superFilters.length; i++) {
        var sf = superFilters[i];
        if (filter.equals(sf)) {
          return true;
        }
      }
      return false;
    }

    var diff: FacetFilter[] = [];
    var numFoundInSubFilters = 0;
    subFilters.forEach((subFilterFilter) => {
      if (filterInSuperFilter(subFilterFilter)) {
        return numFoundInSubFilters++;
      } else {
        return diff.push(subFilterFilter);
      }
    });

    if (numFoundInSubFilters === superFilters.length) {
      return diff;
    } else {
      return null;
    }
  }

  static filterSubset(subFilter: FacetFilter, superFilter: FacetFilter): boolean {
    return Boolean(FacetFilter.filterDiff(subFilter, superFilter));
  }

  static andFiltersByDataset(filters1: FiltersByDataset, filters2: FiltersByDataset): FiltersByDataset {
    var resFilters: FiltersByDataset = {};
    for (var dataset in filters1) {
      if (!filters1.hasOwnProperty(dataset)) continue;
      var filter1 = filters1[dataset];
      var filter2 = filters2[dataset];
      if (!filter2) throw new Error("unmatched datasets");
      // ToDo: what if only filter1 exists?
      resFilters[dataset] = new AndFilter([filter1, filter2]).simplify();
    }
    return resFilters;
  }

  static compare(filter1: FacetFilter, filter2: FacetFilter): number {
    var filter1SortType = filter1._getSortType();
    var filter2SortType = filter2._getSortType();

    var precedence1 = filterSortTypePrecedence[filter1SortType];
    var precedence2 = filterSortTypePrecedence[filter2SortType];
    var precedenceDiff = precedence1 - precedence2;
    if (precedenceDiff !== 0 || precedence1 > 0) {
      return precedenceDiff;
    }
    var attributeDiff = compare(filter1.attribute, filter2.attribute);
    if (attributeDiff !== 0) {
      return attributeDiff;
    }
    precedenceDiff = filterSortTypeSubPrecedence[filter1SortType] - filterSortTypeSubPrecedence[filter2SortType];
    if (precedenceDiff !== 0) {
      return precedenceDiff;
    }
    switch (filter1SortType) {
      case "within":
        return arrayCompare((<WithinFilter>filter1).range, (<WithinFilter>filter2).range);
      case "in":
      case "not in":
        return arrayCompare(filter1._getInValues(), filter2._getInValues());
      case "contains":
        return compare((<ContainsFilter>filter1).value, (<ContainsFilter>filter2).value);
      case "match":
        return compare((<MatchFilter>filter1).expression, (<MatchFilter>filter2).expression);
    }

    return 0;
  }

  static isFacetFilter(candidate: any): boolean {
    return isInstanceOf(candidate, FacetFilter);
  }

  static classMap: any;
  static fromJS(filterSpec: FacetFilterJS): FacetFilter {
    if (typeof filterSpec !== "object") {
      throw new Error("unrecognizable filter");
    }
    if (!filterSpec.hasOwnProperty("type")) {
      throw new Error("type must be defined");
    }
    if (typeof filterSpec.type !== "string") {
      throw new Error("type must be a string");
    }
    var FilterConstructor = FacetFilter.classMap[filterSpec.type];
    if (!FilterConstructor) {
      throw new Error("unsupported filter type '" + filterSpec.type + "'");
    }
    return FilterConstructor.fromJS(filterSpec);
  }

  private stringifier: FilterStringifier;

  static setStringifier(defaultStringifier: FilterStringifier): void {
    this.defaultStringifier = defaultStringifier;
  }

  public setStringifier(stringifier: FilterStringifier): FacetFilter {
    this.stringifier = stringifier;
    return this;
  }

  public type: string;
  public attribute: string;

  constructor(parameters: FacetFilterValue, dummy: Dummy = null) {
    this.type = parameters.type;
    if (dummy !== dummyObject) {
      throw new TypeError("can not call `new FacetFilter` directly use FacetFilter.fromJS instead");
    }
  }

  /*protected*/
  public _ensureType(filterType: string) {
    if (!this.type) {
      this.type = filterType;
      return;
    }
    if (this.type !== filterType) {
      throw new TypeError("incorrect filter type '" + this.type + "' (needs to be: '" + filterType + "')");
    }
  }

  /*protected*/
  public _validateAttribute(): void {
    if (typeof this.attribute !== "string") {
      throw new TypeError("attribute must be a string");
    }
  }

  /*protected*/
  public _getSortType(): string {
    return this.type;
  }

  /*protected*/
  public _getInValues(): AttributeValue[] {
    return [];
  }

  public valueOf(): FacetFilterValue {
    return {
      type: this.type
    };
  }

  public toJS(): FacetFilterJS {
    return {
      type: this.type
    };
  }

  public toJSON(): FacetFilterJS {
    return this.toJS();
  }

  public equals(other: FacetFilter): boolean {
    return FacetFilter.isFacetFilter(other) &&
           this.type === other.type &&
           this.attribute === other.attribute;
  }

  public getComplexity(): number {
    return 1;
  }

  public simplify(): FacetFilter {
    return this;
  }

  /**
   * Separates, if possible, the filters with the given attributes from the rest.
   * ToDo: more docs
   * @param attribute
   * @returns {FacetFilter[]}
   */
  public extractFilterByAttribute(attribute: string): FacetFilter[] {
    if (typeof attribute !== "string") {
      throw new TypeError("must have an attribute");
    }
    if (!this.attribute || this.attribute !== attribute) {
      return [this, FacetFilter.TRUE];
    } else {
      return [FacetFilter.TRUE, this];
    }
  }

  public toString(): string {
    var stringifier = this.stringifier || FacetFilter.defaultStringifier;
    return stringifier.stringify(this);
  }

  public toHash(): string {
    throw new Error("can not call FacetFilter.toHash directly");
  }

  public getFilterFn(): FilterFn {
    throw new Error("can not call FacetFilter.getFilterFn directly");
  }
}
check = FacetFilter;

export class TrueFilter extends FacetFilter {
  static fromJS(parameters: FacetFilterJS): TrueFilter {
    return new TrueFilter(<FacetFilterValue>parameters);
  }

  constructor(parameters: FacetFilterValue = {}) {
    super(parameters, dummyObject);
    this._ensureType("true");
  }

  public getFilterFn(): FilterFn {
    return () => true;
  }

  public toHash(): string {
    return "T";
  }
}

export class FalseFilter extends FacetFilter {
  static fromJS(parameters: FacetFilterJS): FalseFilter {
    return new FalseFilter(parameters);
  }

  constructor(parameters = {}) {
    super(parameters, dummyObject);
    this._ensureType("false");
  }

  public getFilterFn(): FilterFn {
    return () => false;
  }

  public toHash(): string {
    return "F";
  }
}

export class IsFilter extends FacetFilter {
  static fromJS(parameters: FacetFilterJS): IsFilter {
    return new IsFilter(<FacetFilterValue>parameters);
  }

  public value: any;

  constructor(parameters: FacetFilterValue) {
    this.attribute = parameters.attribute;
    this.value = parameters.value;
    super(parameters, dummyObject);
    this._ensureType("is");
    this._validateAttribute();
  }

  public _getSortType() {
    return "in";
  }

  public _getInValues() {
    return [this.value];
  }

  public valueOf() {
    var filter = super.valueOf();
    filter.attribute = this.attribute;
    filter.value = this.value;
    return filter;
  }

  public toJS() {
    return <FacetFilterJS>this.valueOf();
  }

  public equals(other: FacetFilter): boolean {
    return super.equals(other) &&
           this.value === (<IsFilter>other).value;
  }

  public getFilterFn(): FilterFn {
    var attribute = this.attribute;
    var value = this.value;
    return (d) => d[attribute] === value;
  }

  public toHash(): string {
    return "IS:" + this.attribute + ":" + this.value;
  }
}

export class InFilter extends FacetFilter {
  static fromJS(parameters: FacetFilterJS): InFilter {
    return new InFilter(<FacetFilterValue>parameters);
  }

  private simple: boolean;
  public values: AttributeValue[];

  constructor(parameters: FacetFilterValue) {
    this.attribute = parameters.attribute;
    this.values = parameters.values;
    super(parameters, dummyObject);
    this._ensureType("in");
    this._validateAttribute();
    if (!Array.isArray(this.values)) {
      throw new TypeError("`values` must be an array");
    }
  }

  public _getInValues(): AttributeValue[] {
    return this.values;
  }

  public valueOf() {
    var filter = super.valueOf();
    filter.attribute = this.attribute;
    filter.values = this.values;
    return filter;
  }

  public toJS() {
    var filter = super.toJS();
    filter.attribute = this.attribute;
    filter.values = this.values;
    return filter;
  }

  public simplify(): FacetFilter {
    if (this.simple) return this;

    var vs = union(this.values);
    switch (vs.length) {
      case 0:
        return FacetFilter.FALSE;
      case 1:
        return new IsFilter({
          attribute: this.attribute,
          value: vs[0]
        });
      default:
        vs.sort();
        var simpleFilter = new InFilter({
          attribute: this.attribute,
          values: vs
        });
        simpleFilter.simple = true;
        return simpleFilter;
    }
  }

  public equals(other: FacetFilter): boolean {
    return super.equals(other) &&
           this.values.join(";") === (<InFilter>other).values.join(";");
  }

  public getFilterFn(): FilterFn {
    var attribute = this.attribute;
    var values = this.values;
    return (d) => {
      return values.indexOf(d[attribute]) >= 0;
    };
  }

  public toHash(): string {
    return "IN:" + this.attribute + ":" + (this.values.join(";"));
  }
}

export class ContainsFilter extends FacetFilter {
  static fromJS(parameters: FacetFilterJS): ContainsFilter {
    return new ContainsFilter(<FacetFilterValue>parameters);
  }

  public value: string;

  constructor(parameters: FacetFilterValue) {
    this.attribute = parameters.attribute;
    this.value = <string>parameters.value;
    super(parameters, dummyObject);
    this._ensureType("contains");
    this._validateAttribute();
    if (typeof this.value !== "string") throw new TypeError("contains must be a string");
  }

  public valueOf() {
    var filter = super.valueOf();
    filter.attribute = this.attribute;
    filter.value = <any>this.value;
    return filter;
  }

  public toJS() {
    var filter = super.toJS();
    filter.attribute = this.attribute;
    filter.value = <any>this.value;
    return filter;
  }

  public equals(other: FacetFilter): boolean {
    return super.equals(other) &&
           this.value === (<IsFilter>other).value;
  }

  public getFilterFn(): FilterFn {
    var attribute = this.attribute;
    var value = this.value;
    return (d) => String(d[attribute]).indexOf(value) !== -1;
  }

  public toHash(): string {
    return "C:" + this.attribute + ":" + this.value;
  }
}

export class MatchFilter extends FacetFilter {
  static fromJS(parameters: FacetFilterJS): MatchFilter {
    return new MatchFilter(<FacetFilterValue>parameters);
  }

  public expression: string;

  constructor(parameters: FacetFilterValue) {
    super(parameters, dummyObject);
    this.attribute = parameters.attribute;
    this.expression = parameters.expression;
    this._ensureType("match");
    this._validateAttribute();
    if (!this.expression) {
      throw new Error("must have an expression");
    }
    try {
      new RegExp(this.expression);
    } catch (e) {
      throw new Error("expression must be a valid regular expression");
    }
  }

  public valueOf() {
    var filter = super.valueOf();
    filter.attribute = this.attribute;
    filter.expression = this.expression;
    return filter;
  }

  public toJS() {
    var filter = super.toJS();
    filter.attribute = this.attribute;
    filter.expression = this.expression;
    return filter;
  }

  public equals(other: FacetFilter): boolean {
    return super.equals(other) &&
           this.expression === (<MatchFilter>other).expression;
  }

  public getFilterFn(): FilterFn {
    var attribute = this.attribute
    var expression = new RegExp(this.expression)
    return (d) => expression.test(d[attribute]);
  }

  public toHash(): string {
    return "F:" + this.attribute + ":" + this.expression;
  }
}

export class WithinFilter extends FacetFilter {
  static fromJS(parameters: FacetFilterJS): WithinFilter {
    var range = parameters.range;
    var r0 = range[0];
    var r1 = range[1];
    if (typeof r0 === "string" && typeof r1 === "string") {
      return new WithinFilter({
        attribute: parameters.attribute,
        range: [new Date(r0), new Date(r1)]
      })
    } else {
      return new WithinFilter(<FacetFilterValue>parameters);
    }
  }

  public range: any[];

  constructor(parameters: FacetFilterValue) {
    this.attribute = parameters.attribute;
    this.range = parameters.range;
    super(parameters, dummyObject);
    this._ensureType("within");
    this._validateAttribute();
    if (!(Array.isArray(this.range) && this.range.length === 2)) {
      throw new TypeError("range must be an array of length 2");
    }
    if (isNaN(this.range[0]) || isNaN(this.range[1])) {
      throw new Error("invalid range");
    }
  }

  public valueOf() {
    var filter = super.valueOf();
    filter.attribute = this.attribute;
    filter.range = this.range;
    return filter;
  }

  public toJS() {
    var filterJS = super.toJS();
    filterJS.attribute = this.attribute;
    filterJS.range = this.range;
    return filterJS;
  }

  public equals(other: FacetFilter): boolean {
    if (!super.equals(other)) return false;
    var otherRange = (<WithinFilter>other).range;
    return this.range[0].valueOf() === otherRange[0].valueOf() &&
           this.range[1].valueOf() === otherRange[1].valueOf();
  }

  public getFilterFn(): FilterFn {
    var attribute = this.attribute;
    var range = this.range;
    var r0 = range[0];
    var r1 = range[1];
    if (isInstanceOf(r0, Date)) {
      return (d) => {
        var v = new Date(d[attribute]);
        return r0 <= v && v < r1;
      };
    } else {
      return (d) => {
        var v = Number(d[attribute]);
        return r0 <= v && v < r1;
      };
    }
  }

  public toHash(): string {
    return "W:" + this.attribute + ":" + (this.range[0].valueOf()) + ":" + (this.range[1].valueOf());
  }
}

export class NotFilter extends FacetFilter {
  static fromJS(parameters: FacetFilterJS): NotFilter {
    return new NotFilter(FacetFilter.fromJS(parameters.filter));
  }

  private simple: boolean;
  public filter: FacetFilter;

  constructor(parameters: FacetFilterValue);
  constructor(parameters: FacetFilter);
  constructor(parameters: any) {
    if (!isInstanceOf(parameters, FacetFilter)) {
      super(parameters, dummyObject);
      this.filter = parameters.filter;
    } else {
      this.filter = parameters;
    }
    this._ensureType("not");
  }

  public _getSortType() {
    var filterSortType = this.filter._getSortType();
    return filterSortType === "in" ? "not in" : "not";
  }

  public _getInValues() {
    return this.filter._getInValues();
  }

  public valueOf() {
    var filter = super.valueOf();
    filter.filter = this.filter;
    return filter;
  }

  public toJS() {
    var spec = super.toJS();
    spec.filter = this.filter.toJS();
    return spec;
  }

  public getComplexity() {
    return 1 + this.filter.getComplexity();
  }

  public simplify(): FacetFilter {
    if (this.simple) return this;

    switch (this.filter.type) {
      case "true":
        return FacetFilter.FALSE;
      case "false":
        return FacetFilter.TRUE;
      case "not":
        return (<NotFilter>this.filter).filter.simplify();
      case "and":
        return new OrFilter((<AndFilter>this.filter).filters.map((filter) => new NotFilter(filter))).simplify();
      case "or":
        return new AndFilter((<OrFilter>this.filter).filters.map((filter) => new NotFilter(filter))).simplify();
      default:
        var simpleFilter = new NotFilter(this.filter.simplify());
        simpleFilter.simple = true;
        return simpleFilter;
    }
  }

  public extractFilterByAttribute(attribute: string): FacetFilter[] {
    if (typeof attribute !== "string") {
      throw new TypeError("must have an attribute");
    }
    if (!this.simple) {
      return this.simplify().extractFilterByAttribute(attribute);
    }

    if (!this.filter.attribute) {
      return null;
    }
    if (this.filter.attribute === attribute) {
      return [FacetFilter.TRUE, <FacetFilter>this];
    } else {
      return [<FacetFilter>this, FacetFilter.TRUE];
    }
  }

  public equals(other: FacetFilter): boolean {
    return super.equals(other) &&
           this.filter.equals((<NotFilter>other).filter);
  }

  public getFilterFn(): FilterFn {
    var filter = this.filter.getFilterFn();
    return (d) => !filter(d);
  }

  public toHash(): string {
    return "N(" + (this.filter.toHash()) + ")";
  }
}

export class AndFilter extends FacetFilter {
  static fromJS(parameters: FacetFilterJS): AndFilter {
    return new AndFilter(parameters.filters.map(FacetFilter.fromJS));
  }

  private simple: boolean;
  public filters: FacetFilter[];

  constructor(parameters: FacetFilterValue);
  constructor(parameters: FacetFilter[]);
  constructor(parameters: any) {
    if (Array.isArray(parameters)) parameters = { filters: parameters };
    super(parameters, dummyObject);
    if (!Array.isArray(parameters.filters)) throw new TypeError("filters must be an array");
    this.filters = parameters.filters;
    this._ensureType("and");
  }

  public valueOf() {
    var filter = super.valueOf();
    filter.filters = this.filters;
    return filter;
  }

  public toJS() {
    var spec = super.toJS();
    spec.filters = this.filters.map((filter) => filter.toJS());
    return spec;
  }

  public equals(other: FacetFilter): boolean {
    if (!super.equals(other)) return false;
    var otherFilters = (<AndFilter>other).filters;
    return this.filters.length === otherFilters.length &&
      this.filters.every((filter, i) => filter.equals(otherFilters[i]));
  }

  public getComplexity() {
    var complexity = 1;
    this.filters.forEach((filter) => complexity += filter.getComplexity());
    return complexity;
  }

  public _mergeFilters(filter1: FacetFilter, filter2: FacetFilter): FacetFilter {
    var filter1SortType = filter1._getSortType();
    var filter2SortType = filter2._getSortType();

    if (filter1SortType === "false" || filter2SortType === "false") return FacetFilter.FALSE;
    if (filter1SortType === "true") return filter2;
    if (filter2SortType === "true") return filter1;

    if (filter1.equals(filter2)) return filter1;

    if (filter1SortType !== filter2SortType) return;

    if (!((filter1.attribute != null) && (filter1.attribute === filter2.attribute))) return;
    var attribute = filter1.attribute;

    switch (filter1SortType) {
      case "within":
        var filter1Range = (<WithinFilter>filter1).range;
        var filter2Range = (<WithinFilter>filter2).range;
        var start1 = filter1Range[0];
        var end1 = filter1Range[1];
        var start2 = filter2Range[0];
        var end2 = filter2Range[1];
        var newStart = larger(start1, start2);
        var newEnd = smaller(end1, end2);
        if (newStart <= newEnd) {
          return new WithinFilter({
            attribute: attribute,
            range: [newStart, newEnd]
          });
        } else {
          return FacetFilter.FALSE;
        }
        break;
      case "in":
        return new InFilter({
          attribute: attribute,
          values: intersection(filter1._getInValues(), filter2._getInValues())
        }).simplify();
      case "not in":
        return new NotFilter(new InFilter({
          attribute: attribute,
          values: intersection(filter1._getInValues(), filter2._getInValues())
        })).simplify();
    }
  }

  public simplify(): FacetFilter {
    if (this.simple) {
      return this;
    }

    var newFilters: FacetFilter[] = [];
    this.filters.forEach((filter) => {
      filter = filter.simplify();
      if (filter.type === "and") {
        return Array.prototype.push.apply(newFilters, (<AndFilter>filter).filters);
      } else {
        return newFilters.push(filter);
      }
    });

    newFilters.sort(FacetFilter.compare);

    if (newFilters.length > 1) {
      var mergedFilters: FacetFilter[] = [];
      var acc = newFilters[0];
      var i = 1;
      while (i < newFilters.length) {
        var currentFilter = newFilters[i];
        var merged = this._mergeFilters(acc, currentFilter);
        if (merged) {
          acc = merged;
        } else {
          mergedFilters.push(acc);
          acc = currentFilter;
        }
        i++;
      }
      if (acc.type === "false") return FacetFilter.FALSE;
      if (acc.type !== "true") mergedFilters.push(acc);
      newFilters = mergedFilters;
    }

    switch (newFilters.length) {
      case 0:
        return FacetFilter.TRUE;
      case 1:
        return newFilters[0];
      default:
        var simpleFilter = new AndFilter(newFilters)
        simpleFilter.simple = true;
        return simpleFilter;
    }
  }

  public extractFilterByAttribute(attribute: string): FacetFilter[] {
    if (typeof attribute !== "string") {
      throw new TypeError("must have an attribute");
    }
    if (!this.simple) {
      return this.simplify().extractFilterByAttribute(attribute);
    }

    var remainingFilters: FacetFilter[] = [];
    var extractedFilters: FacetFilter[] = [];
    var filters = this.filters;
    for (var i = 0; i < filters.length; i++) {
      var filter = filters[i];
      var extract = filter.extractFilterByAttribute(attribute);
      if (extract === null) return null;
      remainingFilters.push(extract[0]);
      extractedFilters.push(extract[1]);
    }

    return [new AndFilter(remainingFilters).simplify(), new AndFilter(extractedFilters).simplify()];
  }

  public getFilterFn(): FilterFn {
    var filters = this.filters.map((f) => f.getFilterFn());
    return (d) => {
      for (var i = 0; i < filters.length; i++) {
        var filter = filters[i];
        if (!filter(d)) return false;
      }
      return true;
    };
  }

  public toHash(): string {
    return "(" + (this.filters.map((filter) => filter.toHash()).join(")^(")) + ")";
  }
}


export class OrFilter extends FacetFilter {
  static fromJS(parameters: FacetFilterJS): OrFilter {
    return new OrFilter(parameters.filters.map(FacetFilter.fromJS));
  }

  private simple: boolean;
  public filters: FacetFilter[];

  constructor(parameters: FacetFilterValue);
  constructor(parameters: FacetFilter[]);
  constructor(parameters: any) {
    if (Array.isArray(parameters)) parameters = { filters: parameters };
    super(parameters, dummyObject);
    if (!Array.isArray(parameters.filters)) throw new TypeError("filters must be an array");
    this.filters = parameters.filters;
    this._ensureType("or");
  }

  public valueOf() {
    var filter = super.valueOf();
    filter.filters = this.filters;
    return filter;
  }

  public toJS() {
    var spec = super.toJS();
    spec.filters = this.filters.map((filter) => filter.toJS());
    return spec;
  }

  public equals(other: FacetFilter): boolean {
    if (!super.equals(other)) return false;
    var otherFilters = (<OrFilter>other).filters;
    return this.filters.length === otherFilters.length &&
           this.filters.every((filter, i) => filter.equals(otherFilters[i]));
  }

  public getComplexity() {
    var complexity = 1;
    this.filters.forEach((filter) => {
      complexity += filter.getComplexity();
    });
    return complexity;
  }

  public _mergeFilters(filter1: FacetFilter, filter2: FacetFilter): FacetFilter {
    var filter1SortType = filter1._getSortType();
    var filter2SortType = filter2._getSortType();

    if (filter1SortType === "true" || filter2SortType === "true") return FacetFilter.TRUE;
    if (filter1SortType === "false") return filter2;
    if (filter2SortType === "false") return filter1;

    if (!((filter1.attribute != null) && (filter1.attribute === filter2.attribute))) {
      return null;
    }
    var attribute = filter1.attribute;

    if (filter1.equals(filter2)) {
      return filter1;
    }

    if (filter1SortType !== filter2SortType) {
      return null;
    }

    switch (filter1SortType) {
      case "within":
        var filter1Range = (<WithinFilter>filter1).range;
        var filter2Range = (<WithinFilter>filter2).range;
        if (!rangesIntersect(filter1Range, filter2Range)) return;
        var start1 = filter1Range[0];
        var end1 = filter1Range[1];
        var start2 = filter2Range[0];
        var end2 = filter2Range[1];
        return new WithinFilter({
          attribute: filter1.attribute,
          range: [smaller(start1, start2), larger(end1, end2)]
        });
      case "in":
        return new InFilter({
          attribute: attribute,
          values: union(filter1._getInValues(), filter2._getInValues())
        }).simplify();
      case "not in":
        return new NotFilter(new InFilter({
          attribute: attribute,
          values: union(filter1._getInValues(), filter2._getInValues())
        })).simplify();
    }

  }

  public simplify(): FacetFilter {
    if (this.simple) return this;

    var newFilters: FacetFilter[] = [];
    this.filters.forEach((filter) => {
      filter = filter.simplify();
      if (filter.type === "or") {
        return Array.prototype.push.apply(newFilters, (<OrFilter>filter).filters);
      } else {
        return newFilters.push(filter);
      }
    });

    newFilters.sort(FacetFilter.compare);

    if (newFilters.length > 1) {
      var mergedFilters: FacetFilter[] = [];
      var acc = newFilters[0];
      var i = 1;
      while (i < newFilters.length) {
        var currentFilter = newFilters[i];
        var merged = this._mergeFilters(acc, currentFilter);
        if (merged) {
          acc = merged;
        } else {
          mergedFilters.push(acc);
          acc = currentFilter;
        }
        i++;
      }
      if (acc.type === "true") return FacetFilter.TRUE;
      if (acc.type !== "false") mergedFilters.push(acc);
      newFilters = mergedFilters;
    }

    switch (newFilters.length) {
      case 0:
        return FacetFilter.FALSE;
      case 1:
        return newFilters[0];
      default:
        var simpleFilter = new OrFilter(newFilters);
        simpleFilter.simple = true;
        return simpleFilter;
    }
  }

  public extractFilterByAttribute(attribute: string): FacetFilter[] {
    if (typeof attribute !== "string") throw new TypeError("must have an attribute");
    if (!this.simple) return this.simplify().extractFilterByAttribute(attribute);

    var hasRemaining = false;
    var hasExtracted = false;
    var filters = this.filters;
    for (var i = 0; i < filters.length; i++) {
      var filter = filters[i];
      var extracts = filter.extractFilterByAttribute(attribute);
      if (!extracts) {
        return null;
      }
      hasRemaining || (hasRemaining = extracts[0].type !== "true");
      hasExtracted || (hasExtracted = extracts[1].type !== "true");
    }

    if (hasRemaining) {
      if (hasExtracted) {
        return null;
      } else {
        return [<FacetFilter>this, FacetFilter.TRUE];
      }
    } else {
      if (!hasExtracted) {
        throw new Error("something went wrong");
      }
      return [FacetFilter.TRUE, <FacetFilter>this];
    }
  }

  public getFilterFn(): FilterFn {
    var filters = this.filters.map((f) => f.getFilterFn());
    return (d) => {
      for (var i = 0, len = filters.length; i < len; i++) {
        var filter = filters[i];
        if (filter(d)) {
          return true;
        }
      }
      return false;
    };
  }

  public toHash(): string {
    return "(" + (this.filters.map((filter) => filter.toHash()).join(")v(")) + ")";
  }
}

FacetFilter.TRUE = new TrueFilter();
FacetFilter.FALSE = new FalseFilter();

FacetFilter.classMap = {
  "true": TrueFilter,
  "false": FalseFilter,
  "is": IsFilter,
  "in": InFilter,
  "contains": ContainsFilter,
  "match": MatchFilter,
  "within": WithinFilter,
  "not": NotFilter,
  "or": OrFilter,
  "and": AndFilter
};
