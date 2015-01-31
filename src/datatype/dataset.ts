/// <reference path="../../typings/tsd.d.ts" />
"use strict";

import Basics = require("../basics") // Prop up
import Lookup = Basics.Lookup;

import HigherObjectModule = require("higher-object");
import isInstanceOf = HigherObjectModule.isInstanceOf;
import ImmutableClass = HigherObjectModule.ImmutableClass;
import ImmutableInstance = HigherObjectModule.ImmutableInstance;

import TimeRangeModule = require('./timeRange');
import TimeRange = TimeRangeModule.TimeRange;

export interface Dummy {}
export var dummyObject: Dummy = {};

export interface Datum {
  [name: string]: any;
}

export interface DatasetValue {
  dataset: string;
  data?: Datum[];
}

export interface DatasetJS {
  dataset: string;
  data?: Datum[];
}

// =====================================================================================
// =====================================================================================

var check: ImmutableClass<DatasetValue, DatasetJS>;
export class Dataset implements ImmutableInstance<DatasetValue, DatasetJS> {
  static category = 'DATASET';
  static isDataset(candidate: any): boolean {
    return isInstanceOf(candidate, Dataset);
  }

  static classMap: Lookup<typeof Dataset> = {};
  static fromJS(datasetJS: DatasetJS): Dataset {
    if (!datasetJS.hasOwnProperty("dataset")) {
      throw new Error("dataset must be defined");
    }
    var dataset = datasetJS.dataset;
    if (typeof dataset !== "string") {
      throw new Error("dataset must be a string");
    }
    var ClassFn = Dataset.classMap[dataset];
    if (!ClassFn) {
      throw new Error("unsupported dataset '" + dataset + "'");
    }

    return ClassFn.fromJS(datasetJS);
  }

  public dataset: string;

  constructor(parameters: DatasetValue, dummy: Dummy = null) {
    this.dataset = parameters.dataset;
    if (dummy !== dummyObject) {
      throw new TypeError("can not call `new Dataset` directly use Dataset.fromJS instead");
    }
  }

  protected _ensureDataset(dataset: string) {
    if (!this.dataset) {
      this.dataset = dataset;
      return;
    }
    if (this.dataset !== dataset) {
      throw new TypeError("incorrect dataset '" + this.dataset + "' (needs to be: '" + dataset + "')");
    }
  }

  public valueOf(): DatasetValue {
    return {
      dataset: this.dataset
    };
  }

  public toJS(): DatasetJS {
    return {
      dataset: this.dataset
    };
  }

  public toString(): string {
    return "<Dataset:" + this.dataset + ">";
  }

  public toJSON(): DatasetJS {
    return this.toJS();
  }

  public equals(other: Dataset): boolean {
    return Dataset.isDataset(other) &&
      this.dataset === other.dataset;
  }
}
check = Dataset;

// =====================================================================================
// =====================================================================================

function datumToJS(datum: Datum): Datum {
  var js: Datum = {};
  for (var k in datum) {
    if (!datum.hasOwnProperty(k)) continue;
    var v: any = datum[k];
    if (v == null) {
      v = null;
    } else {
      var typeofV = typeof v;
      if (typeofV === 'object') {
        var cat = v.constructor.category;
        v = v.toJS();
        v.cat = cat;
      } else if (typeofV === 'number' && !isFinite(v)) {
        v = { cat: 'NUMBER', value: String(v) };
      }
    }
    js[k] = v;
  }
  return js;
}

function datumFromJS(js: Datum): Datum {
  if (typeof js !== 'object') throw new TypeError("datum must be an object");

  var datum: Datum = {};
  for (var k in js) {
    if (!js.hasOwnProperty(k)) continue;
    var v: any = js[k];
    if (v == null) {
      v = null;
    } else if (Array.isArray(v)) {
      // ToDo: parse it as a dataset
    } else if (typeof v === 'object') {
      switch (v.cat) {
        case 'NUMBER':
          var infinityMatch = String(v.value).match(/^([-+]?)Infinity$/);
          if (infinityMatch) {
            v = infinityMatch[1] === '-' ? -Infinity : Infinity;
          } else {
            throw new Error("bad number value '" + String(v.value) + "'");
          }
          break;

        case 'TIME_RANGE':
          v = TimeRange.fromJS(v);
          break;

        // ToDo: fill this in.

        default:
          throw new Error('can not have an object without a `cat` as a datum value')
      }
    }
    datum[k] = v;
  }

  return datum;
}

export class BaseDataset extends Dataset {
  static category = 'DATASET';
  static fromJS(datasetJS: DatasetJS): BaseDataset {
    return new BaseDataset({
      dataset: datasetJS.dataset,
      data: datasetJS.data.map(datumFromJS)
    })
  }

  public data: Datum[];

  constructor(parameters: DatasetValue) {
    super(parameters, dummyObject);
    this.data = parameters.data;
    this._ensureDataset("base");
    if (!Array.isArray(this.data)) {
      throw new TypeError("must have a `data` array")
    }
  }

  public valueOf(): DatasetValue {
    var value = super.valueOf();
    value.data = this.data;
    return value;
  }

  public toJS(): DatasetJS {
    var js = super.toJS();
    js.data = this.data.map(datumToJS);
    return js;
  }

  public equals(other: BaseDataset): boolean {
    return super.equals(other) &&
      this.data.length === other.data.length;
      // ToDo: probably add something else here?
  }
}

Dataset.classMap['base'] = BaseDataset;

// =====================================================================================
// =====================================================================================
