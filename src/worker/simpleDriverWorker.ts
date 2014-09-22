"use strict";

import Basics = require("../basics") // Prop up
import Lookup = Basics.Lookup;

import simpleDriverModule = require("../driver/simpleDriver");
import simpleDriver = simpleDriverModule.simpleDriver;

import workerBaseModule = require("./workerBase");
import workerBase = workerBaseModule.workerBase;

workerBase(simpleDriver);
