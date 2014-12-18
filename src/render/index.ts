"use strict";

import FacetVis = require("./facetVis");

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
