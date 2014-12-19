/// <reference path="../../typings/tsd.d.ts" />
"use strict";

import Basics = require("../basics") // Prop up
import Lookup = Basics.Lookup;

import HigherObjectModule = require("higher-object");
import isInstanceOf = HigherObjectModule.isInstanceOf;
import ImmutableClass = HigherObjectModule.ImmutableClass;
import ImmutableInstance = HigherObjectModule.ImmutableInstance;

import FacetQueryModule = require("../query/index");
import FacetFilter = FacetQueryModule.FacetFilter;
import AndFilter = FacetQueryModule.AndFilter;

import Driver = require("../driverCommon");

export class Dataset {
  public driver: Driver.FacetDriver;
  public dataFilter: FacetFilter;

  static isDataset(candidate: any): boolean {
    return isInstanceOf(candidate, Dataset);
  }

  constructor(driver: Driver.FacetDriver, filter: FacetFilter = FacetFilter.TRUE) {
    this.driver = driver;
    this.dataFilter = filter;
  }

  public filter(filter: FacetFilter): Dataset {
    return new Dataset(this.driver, new AndFilter([this.dataFilter, filter]).simplify());
  }
}
