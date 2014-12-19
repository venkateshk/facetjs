"use strict";

import Basics = require("../basics") // Prop up
import Lookup = Basics.Lookup;

import FacetQueryModule = require("../query/index");
import FacetSplit = FacetQueryModule.FacetSplit;

import FacetVisModule = require("./facetVis");
import FacetVis = FacetVisModule.FacetVis;

import DatasetModule = require("./dataset");
import Dataset = DatasetModule.Dataset;

import Driver = require("../driverCommon");

//exports.filter = require("./filter");
//exports.split = require("./split");
//exports.apply = require("./apply");
//exports.combine = require("./combine");
//exports.use = require("./use");
//exports.scale = require("./scale");
//exports.space = require("./space");
//exports.layout = require("./layout");
//exports.transform = require("./transform");
//exports.plot = require("./plot");
//exports.connector = require("./connector");

export function define(renderType: string) {
  return new FacetVis({
    renderType: renderType
  });
}

export function facet(name: string, split: FacetSplit) {
  return new FacetVis({

  });
}


export function dataset(driver: Driver.FacetDriver) {
  return new Dataset(driver);
}
