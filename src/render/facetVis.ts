/// <reference path="../../typings/tsd.d.ts" />
"use strict";

import Basics = require("../basics"); // Prop up
import Lookup = Basics.Lookup;

import HigherObjectModule = require("higher-object");
import isInstanceOf = HigherObjectModule.isInstanceOf;
import ImmutableClass = HigherObjectModule.ImmutableClass;
import ImmutableInstance = HigherObjectModule.ImmutableInstance;

import d3 = require("d3");

import FacetQueryModule = require("../query/index");
import FacetQuery = FacetQueryModule.FacetQuery;
import FacetDataset = FacetQueryModule.FacetDataset;
import FacetSplit = FacetQueryModule.FacetSplit;
import FacetApply = FacetQueryModule.FacetApply;

import FacetCombineModule = require("../query/combine");
import FacetCombine = FacetCombineModule.FacetCombine;
import FacetCombineJS = FacetCombineModule.FacetCombineJS;

import SegmentTreeModule = require("../query/segmentTree");
import SegmentTree = SegmentTreeModule.SegmentTree;
import SegmentTreeJS = SegmentTreeModule.SegmentTreeJS;

import ShapeModule = require("./shape");
import Shape = ShapeModule.Shape;
import RectangularShape = ShapeModule.RectangularShape;

import ScaleModule = require("./scale");
import Scale = ScaleModule.Scale;

import MarkModule = require("./mark");
import Mark = MarkModule.Mark;

export interface FacetVisValue {
  selector?: string;
  renderType?: string;
  split?: FacetSplit;
  splitName?: string;
}

export interface Stat {
  [name: string]: any;
}

function statToJS(stat: Stat): Stat {
  var js: Stat = {};
  for (var k in stat) {
    if (!stat.hasOwnProperty(k)) continue;
    var v: any = stat[k];
    js[k] = Array.isArray(v) ? v.map(statToJS) : (typeof v.toJS === 'function' ? v.toJS() : v);
  }
  return js;
}

export class StatBase implements Stat {
  [name: string]: any;

  // Future static fromJS
  //protoLink = (object, parent = null) ->
  //  return object unless typeof object is 'object'
  //  if Array.isArray(object)
  //    return object.map((o) -> protoLink(o, parent))
  //  newObject = new Object(parent)
  //  for own k, v of object
  //    console.log("k", k);
  //    newObject[k] = protoLink(v, newObject)
  //  return newObject


  public toJS(): any {
    return statToJS(this)
  }

  public toString(): string {
    return 'Stat'
  }
}

interface Def {
  name: string;
  thing: any;
}

export class FacetVis {
  public parent: FacetVis;
  public renderType: string;
  public split: FacetSplit;
  public splitName: string;
  public renders: Mark[];
  public combineOperations: any[];
  public selector: string;
  public datasets: Lookup<FacetDataset> = {};
  public numDatasets: number = 0;

  private defs: Def[] = [];

  static isFacetVis(candidate: any): boolean {
    return isInstanceOf(candidate, FacetVis);
  }

  constructor(parameters: FacetVisValue) {
    this.selector = parameters.selector;
    this.renderType = parameters.renderType;
    this.split = parameters.split;
    this.splitName = parameters.splitName;
  }

  public toJS(): FacetVisValue {
    var value: FacetVisValue = {};
    if(this.selector) value.selector = this.selector;
    if(this.renderType) value.renderType = this.renderType;
    if(this.split) value.split = this.split;
    return value;
  }

  public container(selector: any): FacetVis {
    if (this.split) {
      throw new Error("Can not only call container in the base");
    }
    this.selector = selector;
    return this;
  }

  public data(name: string, dataset: FacetDataset): FacetVis;
  public data(dataset: FacetDataset): FacetVis;
  public data(name: any, dataset: FacetDataset = null): FacetVis {
    if (this.split) {
      throw new Error("Can not only call data in the base");
    }
    if (!dataset) {
      dataset = name;
      name = "main";
    }
    this.datasets[name] = dataset;
    this.numDatasets++;
    return this;
  }

  public def(name: string, thing: any): FacetVis {
    this.defs.push({
      name: name,
      thing: thing
    });
    return this;
  }

  public sort(attribute: string, direction: string): FacetVis {
    this.combineOperations || (this.combineOperations = []);
    this.combineOperations.push({
      operation: 'sort',
      attribute: attribute,
      direction: direction
    });
    return this;
  }

  public limit(limit: number): FacetVis {
    this.combineOperations || (this.combineOperations = []);
    this.combineOperations.push({
      operation: 'limit',
      limit: limit
    });
    return this;
  }

  public accumulate(name: string, thing: any): FacetVis {
    // ToDo: work out what this will do.
    return this;
  }

  public train(what: string, property: string, expression: any): FacetVis {
    // this.ops.push({ operation: 'train' });
    return this;
  }

  public render(mark: Mark): FacetVis {
    this.renders.push(mark);
    return this;
  }

  /*
  public connector(name, connector) {
    if (typeof connector !== "function") {
      throw new TypeError("not a valid connector");
    }
    this.ops.push({
      operation: "connector",
      name: name,
      connector: connector
    });
    return this;
  }

  public connect(name) {
    this.ops.push({
      operation: "connect",
      name: name
    });
    return this;
  }
  */

  private getQueryParts(): any[] {
    var res: any[] = [];
    var defs = this.defs;

    // Look for filter or split
    if (!this.split) {
      if (this.numDatasets === 0) throw new Error("must have at least one dataset");
      for (var datasetName in this.datasets) {
        if (datasetName === 'main') { // ToDo: fix this hack
          var dataset = this.datasets[datasetName];
          if (dataset.filter.type !== 'true') {
            var filterJS = dataset.filter.toJS();
            filterJS.operation = 'filter';
            res.push(filterJS);
          }
        }
      }
    } else {
      var splitJS = this.split.toJS();
      splitJS.operation = 'split';
      if (this.splitName) {
        splitJS.name = this.splitName;
      }
      res.push(splitJS);
    }

    // Look for applies
    for (var i = 0; i < defs.length; i++) {
      var def = defs[i];
      if (FacetApply.isFacetApply(def.thing)) {
        var apply = <FacetApply>def.thing;
        var applyJS = apply.toJS();
        applyJS.operation = 'apply';
        if (def.name) {
          applyJS.name = def.name;
        }
        res.push(applyJS);
      }
    }

    // Add the combine
    if (this.split) {
      var combineOperations = this.combineOperations || [];
      var combineJS: FacetCombineJS = {
        operation: 'combine',
        method: 'slice',
        sort: {
          compare: 'natural',
          prop: this.splitName,
          direction: 'ascending'
        }
      };
      for (var i = 0; i < combineOperations.length; i++) {
        var combineOperation = combineOperations[i];
        switch (combineOperation.operation) {
          case 'sort':
            combineJS.sort.prop = combineOperation.attribute;
            combineJS.sort.direction = combineOperation.direction;
            break;

          case 'limit':
            combineJS.limit = combineOperation.limit;
            break;

          default:
            throw new Error('unknown combine command');
        }
      }
      if (combineJS.sort.prop) { // Make sure we are not sorting on a prop that does not exist
        res.push(combineJS);
      }
    }

    // Add sub-split
    var numSubSplits = 0;
    for (var i = 0; i < defs.length; i++) {
      var def = defs[i];
      if (FacetVis.isFacetVis(def.thing)) {
        numSubSplits++;
        if (numSubSplits > 1) {
          throw new Error("can only have one sub split for now")
        }
        var subVis = <FacetVis>def.thing;
        res = res.concat(subVis.getQueryParts())
      }
    }

    return res;
  }

  public evaluate(segmentTree: SegmentTree, parentStat: Stat = null): Stat {
    var myStat: Stat = parentStat ? Object.create(parentStat) : new StatBase();

    var splitName = this.splitName;
    if (splitName) {
      myStat[splitName] = segmentTree.prop[splitName];
    }

    var defs = this.defs;
    for (var i = 0; i < defs.length; i++) {
      var def = defs[i];
      var typeofThing = typeof def.thing;
      switch (typeofThing) {
        case 'number':
        case 'string':
          myStat[def.name] = def.thing;
          break;

        case 'function':
          myStat[def.name] = def.thing.call(myStat, myStat, parentStat);
          break;

        case 'object':
          if (FacetApply.isFacetApply(def.thing)) {
            myStat[def.name] = segmentTree.prop[def.name];
          } else if (FacetVis.isFacetVis(def.thing)) {
            var subFacetVis = <FacetVis>(def.thing);
            myStat[def.name] = segmentTree.splits.map((subSegmentTree) => subFacetVis.evaluate(subSegmentTree, myStat));
          } else if (Shape.isShape(def.thing)) {
            myStat[def.name] = (<Shape>(def.thing)).evaluate(myStat);
          }
          break;

        default:
          throw new Error('unsupported def type');
      }
    }

    return myStat;
  }

  /*
  if (FacetApply.isFacetApply(thing)) {
    var applyJS = (<FacetApply>thing
    applyJS.operation = "apply";
    applyJS.name = name;
    this.ops.push(applyJS);
    //this.knownProps[name] = true;
  } else if (Scale.isScale(thing)) {
    // ToDo: fill me in
  } else if (Shape.isShape(thing)) {
    // ToDo: fill me in
  }

  public layout(layout) {
    var subVis;
    if (typeof layout !== "function") {
      throw new TypeError("layout must be a function");
    }
    subVis = new FacetVis(this, "layout", this.knownProps);
    this.ops.push({
      operation: "layout",
      layout: layout,
      vis: subVis
    });
    return subVis;
  }





  public getFlatOperations() {
    var operations, _ref;
    operations = [];
    this.ops.forEach((op) => {
      operations.push(op);
      if ((_ref = op.operation) === "layout" || _ref === "transform") {
        Array.prototype.push.apply(operations, op.vis.getFlatOperations());
        return operations.push({
          operation: "un" + op.operation
        });
      }
    });

    return operations;
  }

  public render(expose, done) {
    var height, operations, parent, querySpec, svg, width;
    if (this.parent) {
      return this.parent.render(expose, done);
    }

    if (typeof expose === "function") {
      done = expose;
      expose = false;
    }

    parent = d3.select(this.selector);
    width = this.width;
    height = this.height;
    if (parent.empty()) {
      throw new Error("could not find the provided selector");
    }

    svg = parent.append("svg").attr({
      "class": "facet loading",
      width: width,
      height: height
    });

    operations = this.getFlatOperations();

    querySpec = operations.filter((_arg) => {
      var operation, _arg;
      operation = _arg.operation;
      return operation === "filter" || operation === "split" || operation === "apply" || operation === "combine";
    });

    this.driver({
      query: new FacetQuery(querySpec)
    }, (err, res) => {
      var allStates, c, connector, curBatch, curConnector, curScale, curState, domain, errorMerrage, i, k, layout, myScale, name, newShapes, nextState, plot, pseudoShapes, range, rootSegment, scale, segment, segmentGroup, segmentGroups, space, stateStack, transform, v, _i, _j, _k, _l, _len, _len1, _len2, _len3, _len4, _m, _ref, _ref1, _ref2, _ref3, _ref4, _results, _results1, _results2, _results3;
      svg.classed("loading", false);
      if (err) {
        svg.classed("error", true);
        errorMerrage = "An error has occurred: " + (typeof err === "string" ? err : err.message);
        if (typeof alert === "function") {
          alert(errorMerrage);
        } else {
          console.log(errorMerrage);
        }
        return;
      }

      stateStack = [
        {
          spaces: [
            new Shape(null, svg, "rectangle", {
              width: width,
              height: height
            })
          ],
          segments: [new Segment(null, res.prop, res.splits)]
        }
      ];
      allStates = stateStack.slice();

      operations.forEach((cmd) => {
        curState = stateStack[stateStack.length - 1];

        switch (cmd.operation) {
          case "split":
            if (curState.pregnant) {
              throw new Error("Can not split (again) in pregnant state");
            }
            segmentGroups = curState.segments.map((segment) => segment.splits = segment.splits.map((_arg) => {
              var prop, splits;
              prop = _arg.prop, splits = _arg.splits;
              prop = _arg.prop, splits = _arg.splits;
              return new Segment(segment, prop, splits);
            }));

            curState.pregnant = true;
            curState.segmentGroups = segmentGroups;
            return curState.nextSegments = flatten(segmentGroups);
          case "filter":
          case "apply":
          case "combine":
            return null;
          case "scale":
            name = cmd.name, scale = cmd.scale;
            _ref = curState.segments;
            _results = [];
            for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
              segment = _ref[i];
              space = curState.spaces[i];
              myScale = scale();
              if (typeof myScale.domain !== "function") {
                throw new TypeError("not a valid scale");
              }
              segment.scale[name] = myScale;
              _results.push(space.scale[name] = myScale);
            }
            return _results;
            break;
          case "domain":
            name = cmd.name, domain = cmd.domain;

            curScale = null;
            (curState.nextSegments || curState.segments).forEach((segment) => {
              c = segment.getScale(name);
              if (c === curScale) {
                return curBatch.push(segment);
              } else {
                if (curScale) {
                  curScale.domain(curBatch, domain);
                }
                curScale = c;
                return curBatch = [segment];
              }
            });

            if (curScale) {
              return curScale.domain(curBatch, domain);
            }
            break;
          case "range":
            name = cmd.name, range = cmd.range;

            curScale = null;
            curState.spaces.forEach((space) => {
              c = space.getScale(name);
              if (c === curScale) {
                return curBatch.push(space);
              } else {
                if (curScale) {
                  if (!curScale.range) {
                    throw new Error("Scale '" + name + "' range can not be trained");
                  }
                  curScale.range(curBatch, range);
                }
                curScale = c;
                return curBatch = [space];
              }
            });

            if (curScale) {
              if (!curScale.range) {
                throw new Error("Scale '" + name + "' range can not be trained");
              }
              return curScale.range(curBatch, range);
            }
            break;
          case "layout":
            if (!curState.pregnant) {
              throw new Error("Must be in pregnant state to layout (split first)");
            }
            layout = cmd.layout;
            newShapes = [];
            _ref1 = curState.segmentGroups;
            for (i = _j = 0, _len1 = _ref1.length; _j < _len1; i = ++_j) {
              segmentGroup = _ref1[i];
              space = curState.spaces[i];
              pseudoShapes = layout(segmentGroup, space);
              pseudoShapes.forEach((pseudoShape) => newShapes.push(new Shape(space, space.node.append("g").attr("transform", pseudoShapeToTransform(pseudoShape)), pseudoShape.type, pseudoShape.attr)));
            }

            nextState = {
              spaces: newShapes,
              segments: curState.nextSegments
            };
            stateStack.push(nextState);
            return allStates.push(nextState);
          case "unlayout":
            return stateStack.pop();
          case "transform":
            transform = cmd.transform;
            nextState = {};
            for (k in curState) {
              v = curState[k];
              nextState[k] = v;
            }

            nextState.spaces = curState.spaces.map((space, i) => {
              var pseudoShape;
              segment = curState.segments[i];
              pseudoShape = transform(segment, space);
              return new Shape(space, space.node.append("g").attr("transform", pseudoShapeToTransform(pseudoShape)), pseudoShape.type, pseudoShape.attr);
            });

            stateStack.push(nextState);
            return allStates.push(nextState);
          case "untransform":
            return stateStack.pop();
          case "plot":
            plot = cmd.plot;
            _ref2 = curState.segments;
            _results1 = [];
            for (i = _k = 0, _len2 = _ref2.length; _k < _len2; i = ++_k) {
              segment = _ref2[i];
              space = curState.spaces[i];
              _results1.push(plot(segment, space));
            }
            return _results1;
            break;
          case "connector":
            name = cmd.name, connector = cmd.connector;
            _ref3 = curState.segments;
            _results2 = [];
            for (i = _l = 0, _len3 = _ref3.length; _l < _len3; i = ++_l) {
              segment = _ref3[i];
              space = curState.spaces[i];
              _results2.push(space.connector[name] = connector(segment, space));
            }
            return _results2;
            break;
          case "connect":
            name = cmd.name;

            curConnector = null;
            curState.spaces.forEach((space) => {
              c = space.getConnector(name);
              if (c === curConnector) {
                return curBatch.push(space);
              } else {
                if (curConnector) {
                  curConnector(curBatch);
                }
                curConnector = c;
                return curBatch = [space];
              }
            });

            if (curConnector) {
              return curConnector(curBatch);
            }
            break;
          default:
            throw new Error("Unknown operation '" + cmd.operation + "'");
        }
      });

      if (typeof done === "function") {
        rootSegment = stateStack[0].segments[0];
        done.call(rootSegment, rootSegment);
      }

      if (expose) {
        allStates.forEach((curState) => {
          _ref4 = curState.segments;
          _results3 = [];
          for (i = _m = 0, _len4 = _ref4.length; _m < _len4; i = ++_m) {
            segment = _ref4[i];
            _results3.push(curState.spaces[i].expose(segment));
          }
          return _results3;
        });
      }

    });

    return this;
  }
  */
}
