"use strict";

import Basics = require("../basics") // Prop up
import Lookup = Basics.Lookup;

function divideLength(length, sizes) {
  var lengthPerSize, totalSize;
  totalSize = 0;
  sizes.forEach((size) => totalSize += size);
  lengthPerSize = length / totalSize;
  return sizes.map((size) => size * lengthPerSize);
}

function stripeTile(dim1, dim2) {
  return (_arg: any = {}) => {
    var gap, size, _arg, _ref;
    _ref = _arg != null ? _arg : {}, gap = _ref.gap, size = _ref.size;
    gap || (gap = 0);
    size = wrapLiteral(size != null ? size : 1);

    return (segments, space) => {
      var availableDim1, dim1s, dimSoFar, maxGap, n, parentDim1, parentDim2;
      n = segments.length;
      if (space.type !== "rectangle") {
        throw new Error("Must have a rectangular space (is " + space.type + ")");
      }
      parentDim1 = space.attr[dim1];
      parentDim2 = space.attr[dim2];
      maxGap = Math.max(0, (parentDim1 - n * 2) / (n - 1));
      gap = Math.min(gap, maxGap);
      availableDim1 = parentDim1 - gap * (n - 1);
      dim1s = divideLength(availableDim1, segments.map(size));

      dimSoFar = 0;
      return segments.map((segment, i) => {
        var curDim1, pseudoSpace;
        curDim1 = dim1s[i];

        pseudoSpace = {
          type: "rectangle",
          x: 0,
          y: 0,
          attr: {}
        };
        pseudoSpace[dim1 === "width" ? "x" : "y"] = dimSoFar;
        pseudoSpace.attr[dim1] = curDim1;
        pseudoSpace.attr[dim2] = parentDim2;

        dimSoFar += curDim1 + gap;
        return pseudoSpace;
      });
    };
  };
}

module.exports = {
  overlap: () => (segments, space) => segments.map((segment) => ({
    type: space.type,
    x: 0,
    y: 0,
    attr: space.attr
  })),
  horizontal: stripeTile("width", "height"),
  vertical: stripeTile("height", "width"),
  horizontalScale: (args) => {
    var flip, scale, use;
    if (!args) {
      throw new Error("Must have args");
    }
    scale = args.scale, use = args.use, flip = args.flip;
    if (!scale) {
      throw new Error("Must have a scale");
    }

    return (segments, space) => {
      var scaleObj, spaceHeight, spaceWidth;
      if (space.type !== "rectangle") {
        throw new Error("Must have a rectangular space (is " + space.type + ")");
      }

      spaceWidth = space.attr.width;
      spaceHeight = space.attr.height;

      scaleObj = segments[0].getScale(scale);
      use || (use = scaleObj.use);

      return segments.map((segment, i) => {
        var int, width, x;
        int = scaleObj.fn(use(segment));

        x = int.start;
        width = int.end - int.start;
        if (flip) {
          x = spaceWidth - x - width;
        }

        return {
          type: "rectangle",
          x: x,
          y: 0,
          attr: {
            width: width,
            height: spaceHeight
          }
        };
      });
    };
  },
  tile: () => {
    throw new Error("not implemented yet");
  }
};
