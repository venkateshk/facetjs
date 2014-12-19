/// <reference path="../../typings/tsd.d.ts" />
"use strict";

import Basics = require("../basics") // Prop up
import Lookup = Basics.Lookup;

import HigherObjectModule = require("higher-object");
import isInstanceOf = HigherObjectModule.isInstanceOf;
import ImmutableClass = HigherObjectModule.ImmutableClass;
import ImmutableInstance = HigherObjectModule.ImmutableInstance;

import d3 = require("d3");

export class Mark {
  public spaceName: string;

  static isMark(candidate: any): boolean {
    return isInstanceOf(candidate, Mark);
  }

  constructor(spaceName: string) {
    this.spaceName = spaceName;
  }

  public toJS() {
    return {
      spaceName: this.spaceName
    };
  }
}

/*
module.exports = {
  box: (args: any = {}) => {
    var color, fill, stroke;
    color = args.color, stroke = args.stroke, fill = args.fill;
    stroke = wrapLiteral(stroke);
    fill = wrapLiteral(fill || color);

    return (segment, space) => {
      if (space.type !== "rectangle") {
        throw new Error("Box must have a rectangle space (is " + space.type + ")");
      }

      createNode(segment, space, "rect", args).attr("x", Math.min(0, space.attr.width)).attr("y", Math.min(0, space.attr.height)).attr("width", Math.abs(space.attr.width)).attr("height", Math.abs(space.attr.height)).style("fill", fill).style("stroke", stroke);
    };
  },
  label: (args: any = {}) => {
    var anchor, angle, baseline, color, size, text;
    color = args.color, text = args.text, size = args.size, anchor = args.anchor, baseline = args.baseline, angle = args.angle;
    color = wrapLiteral(color);
    text = wrapLiteral(text != null ? text : "Label");
    size = wrapLiteral(size);
    anchor = wrapLiteral(anchor);
    baseline = wrapLiteral(baseline);
    angle = wrapLiteral(angle);

    return (segment, space) => {
      var myNode;
      if (space.type !== "point") {
        throw new Error("Label must have a point space (is " + space.type + ")");
      }

      myNode = createNode(segment, space, "text", args);

      if (angle) {
        myNode.attr("transform", "rotate(" + (-angle(segment)) + ")");
      }

      if (baseline) {
        myNode.attr("dy", (segment) => {
          var baselineValue;
          baselineValue = baseline(segment);
          if (baselineValue === "top") {
            return ".71em";
          } else if (baselineValue === "center") {
            return ".35em";
          } else {
            return null;
          }
        });
      }

      myNode.style("font-size", size).style("fill", color).style("text-anchor", anchor).text(text);
    };
  },
  circle: (args: any = {}) => {
    var area, color, fill, radius, stroke;
    radius = args.radius, area = args.area, color = args.color, stroke = args.stroke, fill = args.fill;
    radius = wrapLiteral(radius);
    area = wrapLiteral(area);
    if (area) {
      if (radius) {
        throw new Error("Over-constrained by radius and area");
      } else {
        function radius(segment) {
          return Math.sqrt(area(segment) / Math.PI);
        }
      }
    } else {
      if (!radius) {
        function radius() {
          return 5;
        }
      }
    }

    stroke = wrapLiteral(stroke);
    fill = wrapLiteral(fill || color);

    return (segment, space) => {
      if (space.type !== "point") {
        throw new Error("Circle must have a point space (is " + space.type + ")");
      }

      createNode(segment, space, "circle", args).attr("r", radius).style("fill", fill).style("stroke", stroke);

    };
  },
  line: (args: any = {}) => {
    var color, stroke;
    color = args.color, stroke = args.stroke;

    stroke = wrapLiteral(stroke || color);

    return (segment, space) => {
      if (space.type !== "line") {
        throw new Error("Line must have a line space (is " + space.type + ")");
      }

      createNode(segment, space, "line", args).style("stroke", stroke).attr("x1", -space.attr.length / 2).attr("x2", space.attr.length / 2);

    };
  }
};

function createNode(segment, space, nodeType, _arg) {
 var dash, link, node, opacity, title, visible, _arg;
 title = _arg.title, link = _arg.link, visible = _arg.visible, opacity = _arg.opacity, dash = _arg.dash;
 title = wrapLiteral(title);
 link = wrapLiteral(link);
 visible = wrapLiteral(visible);
 opacity = wrapLiteral(opacity);

 node = space.node;

 if (title || link) {
 node = node.append("a").datum(segment).attr("xlink:title", title).attr("xlink:href", link);
 }

 node = node.append(nodeType).datum(segment).style("opacity", opacity);

 if (visible) {
 node.style("display", visible(segment) ? null : "none");
 }

 if (dash) {
 node.style("stroke-dasharray", dash);
 }

 return node;
 }
*/
