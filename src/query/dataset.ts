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

import FilterModule = require("./filter");
import FacetFilter = FilterModule.FacetFilter;
import FacetFilterJS = FilterModule.FacetFilterJS;

export interface FacetDatasetJS {
  operation?: string;
  name?: string;
  source?: string;
  filter?: FacetFilterJS;
}

export interface FacetDatasetValue {
  name?: string;
  source?: string;
  filter?: FacetFilter;
}

var check: ImmutableClass<FacetDatasetValue, FacetDatasetJS>;
export class FacetDataset implements ImmutableInstance<FacetDatasetValue, FacetDatasetJS> {
  static BASE: FacetDataset;

  static isFacetDataset(candidate: any): boolean {
    return isInstanceOf(candidate, FacetDataset);
  }

  static fromJS(parameters: FacetDatasetJS): FacetDataset {
    return new FacetDataset({
      name: parameters.name,
      source: parameters.source,
      filter: parameters.filter ? FacetFilter.fromJS(parameters.filter) : null
    });
  }

  public name: string;
  public source: string;
  public filter: FacetFilter;

  constructor(parameters: FacetDatasetValue) {
    this.name = parameters.name;
    this.source = parameters.source;
    if (typeof this.name !== "string") {
      throw new TypeError("dataset name must be a string");
    }
    if (typeof this.source !== "string") {
      throw new TypeError("dataset source must be a string");
    }
    if (parameters.filter) {
      if (!FacetFilter.isFacetFilter(parameters.filter)) {
        throw new TypeError("filter must be a FacetFilter");
      }
      this.filter = parameters.filter;
    }
  }

  public toString(): string {
    return "Dataset:" + this.name;
  }

  public getFilter(): FacetFilter {
    return this.filter || FacetFilter.TRUE;
  }

  public valueOf(): FacetDatasetValue {
    var spec: FacetDatasetValue = {
      name: this.name,
      source: this.source
    };
    if (this.filter) {
      spec.filter = this.filter;
    }
    return spec;
  }

  public toJS() {
    var spec: FacetDatasetJS = {
      name: this.name,
      source: this.source
    };
    if (this.filter) {
      spec.filter = this.filter.toJS();
    }
    return spec;
  }

  public toJSON(): FacetDatasetJS {
    return this.toJS();
  }

  public equals(other: FacetDataset) {
    return FacetDataset.isFacetDataset(other) &&
           this.source === other.source &&
           this.getFilter().equals(other.getFilter());
  }
}
check = FacetDataset;

FacetDataset.BASE = new FacetDataset({
  name: "main",
  source: "base"
});
