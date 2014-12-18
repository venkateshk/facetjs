"use strict";

import Basics = require("../basics") // Prop up
import Lookup = Basics.Lookup;

d3 = require("d3");
wrapLiteral = require("./common").wrapLiteral;

module.exports = {
  line: (_arg) => {
    var color, interpolate, opacity, tension, width, _arg;
    color = _arg.color, width = _arg.width, opacity = _arg.opacity, interpolate = _arg.interpolate, tension = _arg.tension;
    color = wrapLiteral(color);
    width = wrapLiteral(width || 1);
    opacity = wrapLiteral(opacity || 1);
    interpolate = wrapLiteral(interpolate);
    tension = wrapLiteral(tension);

    return (segment, space) => {
      var colorValue, invParentMatrix, lineFn, opacityValue, widthValue;
      colorValue = color(segment);
      widthValue = width(segment);
      opacityValue = opacity(segment);

      lineFn = d3.svg.line();
      if (interpolate) {
        lineFn.interpolate(interpolate(segment));
      }
      if (tension) {
        lineFn.tension(tension(segment));
      }

      invParentMatrix = space.node.node().getScreenCTM().inverse();
      return (spaces) => {
        var points;
        points = spaces.map((space) => {
          var e, f, _ref;
          if (space.type !== "point") {
            throw new Error("Line connector must have a point space (is " + space.type + ")");
          }
          _ref = invParentMatrix.multiply(space.node.node().getScreenCTM()), e = _ref.e, f = _ref.f;
          return [e, f];
        });

        space.node.append("path").attr("d", lineFn(points)).style("stroke", colorValue).style("opacity", opacityValue).style("fill", "none").style("stroke-width", widthValue);

      };
    };
  },
  area: (_arg) => {
    var color, interpolate, opacity, tension, width, _arg;
    color = _arg.color, width = _arg.width, opacity = _arg.opacity, interpolate = _arg.interpolate, tension = _arg.tension;
    color = wrapLiteral(color);
    width = wrapLiteral(width || 1);
    opacity = wrapLiteral(opacity);
    interpolate = wrapLiteral(interpolate);
    tension = wrapLiteral(tension);

    return (segment, space) => {
      var areaFn, colorValue, invParentMatrix, opacityValue, widthValue;
      colorValue = color(segment);
      widthValue = width(segment);
      opacityValue = opacity(segment);

      areaFn = d3.svg.area().x0((d) => d[0]).y0((d) => d[1]).x1((d) => d[2]).y1((d) => d[3]);
      if (interpolate) {
        areaFn.interpolate(interpolate(segment));
      }
      if (tension) {
        areaFn.tension(tension(segment));
      }

      invParentMatrix = space.node.node().getScreenCTM().inverse();
      return (spaces) => {
        var points;
        points = spaces.map((space) => {
          var a, b, e, f, len, _ref;
          if (space.type !== "line") {
            throw new Error("Line connector must have a point space (is " + space.type + ")");
          }
          len = space.length / 2;
          _ref = invParentMatrix.multiply(space.node.node().getScreenCTM()), a = _ref.a, b = _ref.b, e = _ref.e, f = _ref.f;

          return [-a * len + e, -b * len + f, +a * len + e, +b * len + f];
        });

        space.node.append("path").attr("d", areaFn(points)).style("stroke", "none").style("opacity", opacityValue).style("fill", colorValue).style("stroke-width", widthValue);

      };
    };
  }
};
