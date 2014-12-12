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

import SegmentTreeModule = require("./segmentTree");
import SegmentTree = SegmentTreeModule.SegmentTree;
import Prop = SegmentTreeModule.Prop;

export interface DirectionFn {
  (a: any, b: any): number;
}

export interface CompareFn {
  (a: Prop, b: Prop): number;
}

export interface SegmentCompareFn {
  (a: SegmentTree, b: SegmentTree): number;
}

interface DirectionFnMap {
  [direction: string]: DirectionFn;
}

var directionFns: DirectionFnMap = {
  ascending: (a: any, b: any): number => {
    if (Array.isArray(a)) a = a[0];
    if (Array.isArray(b)) b = b[0];
    return a < b ? -1 : a > b ? 1 : a >= b ? 0 : NaN;
  },
  descending: (a: any, b: any): number => {
    if (Array.isArray(a)) a = a[0];
    if (Array.isArray(b)) b = b[0];
    return b < a ? -1 : b > a ? 1 : b >= a ? 0 : NaN;
  }
};

export interface FacetSortJS {
  compare: string;
  prop: string;
  direction: string;
}

var check: ImmutableClass<FacetSortJS, FacetSortJS>;
export class FacetSort implements ImmutableInstance<FacetSortJS, FacetSortJS> {
  static isFacetSort(candidate: any): boolean {
    return isInstanceOf(candidate, FacetSort);
  }

  static classMap: any;
  static fromJS(parameters: FacetSortJS) {
    if (typeof parameters !== "object") {
      throw new Error("unrecognizable sort");
    }
    if (!parameters.hasOwnProperty("compare")) {
      throw new Error("compare must be defined");
    }
    if (typeof parameters.compare !== "string") {
      throw new Error("compare must be a string");
    }
    var SortConstructor = FacetSort.classMap[parameters.compare];
    if (!SortConstructor) {
      throw new Error("unsupported compare '" + parameters.compare + "'");
    }
    return SortConstructor.fromJS(parameters);
  }

  public compare: string;
  public prop: string;
  public direction: string;

  constructor(parameters: FacetSortJS) {
    this.compare = parameters.compare;
    this.prop = parameters.prop;
    this.direction = parameters.direction;
    this._verifyProp();
    this._verifyDirection();
  }

  public _ensureCompare(compare: string) {
    if (!this.compare) {
      this.compare = compare;
      return;
    }
    if (this.compare !== compare) {
      throw new TypeError("incorrect sort compare '" + this.compare + "' (needs to be: '" + compare + "')");
    }
  }

  public _verifyProp(): void {
    if (typeof this.prop !== "string") {
      throw new TypeError("sort prop must be a string");
    }
  }

  public _verifyDirection(): void {
    if (!directionFns[this.direction]) {
      throw new Error("direction must be 'descending' or 'ascending'");
    }
  }

  public toString(): string {
    return "base sort";
  }

  public valueOf(): FacetSortJS {
    return {
      compare: this.compare,
      prop: this.prop,
      direction: this.direction
    };
  }

  public toJS(): FacetSortJS {
    return this.valueOf();
  }

  public toJSON(): FacetSortJS {
    return this.valueOf();
  }

  public getDirectionFn(): DirectionFn {
    return directionFns[this.direction];
  }

  public getCompareFn(): CompareFn {
    throw new Error("can not call FacetSort.getCompareFn directly");
  }

  public getSegmentCompareFn(): SegmentCompareFn {
    var compareFn = this.getCompareFn();
    return (a: SegmentTree, b: SegmentTree): number => compareFn(a.prop, b.prop);
  }

  public equals(other: FacetSort) {
    return FacetSort.isFacetSort(other) &&
           this.compare === other.compare &&
           this.prop === other.prop &&
           this.direction === other.direction;
  }
}
check = FacetSort;

export class NaturalSort extends FacetSort {
  static fromJS(parameters: FacetSortJS) {
    return new NaturalSort(parameters);
  }

  constructor(parameters: FacetSortJS) {
    super(parameters);
    this._ensureCompare("natural");
  }

  public toString(): string {
    return this.compare + "(" + this.prop + ", " + this.direction + ")";
  }

  public getCompareFn(): CompareFn {
    var directionFn = this.getDirectionFn();
    var prop = this.prop;
    return (a, b) => directionFn(a[prop], b[prop]);
  }
}

export class CaseInsensitiveSort extends FacetSort {
  static fromJS(parameters: FacetSortJS) {
    return new CaseInsensitiveSort(parameters);
  }

  constructor(parameters: FacetSortJS) {
    super(parameters);
    this._ensureCompare("caseInsensitive");
  }

  public toString(): string {
    return this.compare + "(" + this.prop + ", " + this.direction + ")";
  }

  public getCompareFn(): CompareFn {
    var directionFn = this.getDirectionFn();
    var prop = this.prop;
    return (a, b) => directionFn((<any>a[prop]).toLowerCase(), (<any>b[prop]).toLowerCase()); // ToDo: resolve <any>
  }
}

FacetSort.classMap = {
  "natural": NaturalSort,
  "caseInsensitive": CaseInsensitiveSort
};


