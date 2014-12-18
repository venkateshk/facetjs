// d3 = require("d3");
FacetQuery = require("../query").FacetQuery;
Segment = require("./segment");
Space = require("./space");

function clone(obj) {
  var k, newObj, v;
  newObj = {};
  for (k in obj) {
    v = obj[k];
    newObj[k] = v;
  }
  return newObj;
}

function flatten(arrays) {
  var flat;
  flat = [];
  arrays.forEach((array) => array.map((a) => flat.push(a)));
  return flat;
}

function pseudoSpaceToTransform(_arg) {
  var a, transformStr, x, y, _arg;
  x = _arg.x, y = _arg.y, a = _arg.a;
  transformStr = "translate(" + x + "," + y + ")";
  if (a) {
    transformStr += " rotate(" + a + ")";
  }
  return transformStr;
}

export interface FacetVisParameters {
  parentAttributes: Lookup<any>;
}

export class FacetVis {
  constructor(parameters: FacetVisParameters) {
    if (args.length === 4) {
      this.selector = args[0], this.width = args[1], this.height = args[2], this.driver = args[3];
      this.knownProps = {};
    } else {
      this.parent = args[0], this.from = args[1], this.knownProps = args[2];
    }
    this.ops = [];
  }

  public filter(filter) {
    if (this.parent) {
      throw new Error("can only filter on the base instance");
    }
    filter = clone(filter);
    filter.operation = "filter";
    this.ops.push(filter);
    return this;
  }

  public split(name, split) {
    split = clone(split);
    split.operation = "split";
    split.name = name;
    this.ops.push(split);
    this.knownProps[name] = true;
    return this;
  }

  public apply(name, apply) {
    apply = clone(apply);
    apply.operation = "apply";
    apply.name = name;
    this.ops.push(apply);
    this.knownProps[name] = true;
    return this;
  }

  public combine(_arg) {
    var combineCmd, limit, method, sort, _arg, _base;
    method = _arg.method, sort = _arg.sort, limit = _arg.limit;
    combineCmd = {
      operation: "combine",
      method: method
    };
    if (sort) {
      if (!this.knownProps[sort.prop]) {
        throw new Error("can not sort on unknown prop '" + sort.prop + "'");
      }
      combineCmd.sort = sort;
      if ((_base = combineCmd.sort).compare == null) {
        _base.compare = "natural";
      }
    }

    if (limit != null) {
      combineCmd.limit = limit;
    }

    this.ops.push(combineCmd);
    return this;
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

  public scale(name, scale) {
    if (typeof scale !== "function") {
      throw new TypeError("not a valid scale");
    }
    this.ops.push({
      operation: "scale",
      name: name,
      scale: scale
    });
    return this;
  }

  public domain(name, domain) {
    this.ops.push({
      operation: "domain",
      name: name,
      domain: domain
    });
    return this;
  }

  public range(name, range) {
    this.ops.push({
      operation: "range",
      name: name,
      range: range
    });
    return this;
  }

  public plot(plot) {
    if (typeof plot !== "function") {
      throw new TypeError("plot must be a function");
    }
    this.ops.push({
      operation: "plot",
      plot: plot
    });
    return this;
  }

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
      var allStates, c, connector, curBatch, curConnector, curScale, curState, domain, errorMerrage, i, k, layout, myScale, name, newSpaces, nextState, plot, pseudoSpaces, range, rootSegment, scale, segment, segmentGroup, segmentGroups, space, stateStack, transform, v, _i, _j, _k, _l, _len, _len1, _len2, _len3, _len4, _m, _ref, _ref1, _ref2, _ref3, _ref4, _results, _results1, _results2, _results3;
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
            new Space(null, svg, "rectangle", {
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
            newSpaces = [];
            _ref1 = curState.segmentGroups;
            for (i = _j = 0, _len1 = _ref1.length; _j < _len1; i = ++_j) {
              segmentGroup = _ref1[i];
              space = curState.spaces[i];
              pseudoSpaces = layout(segmentGroup, space);
              pseudoSpaces.forEach((pseudoSpace) => newSpaces.push(new Space(space, space.node.append("g").attr("transform", pseudoSpaceToTransform(pseudoSpace)), pseudoSpace.type, pseudoSpace.attr)));
            }

            nextState = {
              spaces: newSpaces,
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
              var pseudoSpace;
              segment = curState.segments[i];
              pseudoSpace = transform(segment, space);
              return new Space(space, space.node.append("g").attr("transform", pseudoSpaceToTransform(pseudoSpace)), pseudoSpace.type, pseudoSpace.attr);
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
}
