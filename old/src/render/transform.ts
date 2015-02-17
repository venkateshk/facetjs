"use strict";

import Basics = require("../basics") // Prop up
import Lookup = Basics.Lookup;

var Interval, isInstanceOf, wrapLiteral;

wrapLiteral = require("./common").wrapLiteral;
Interval = require("./interval");
isInstanceOf = require("../utils").isInstanceOf;

function pointOnPoint(args, leftName, rightName) {
  var left, right;
  left = wrapLiteral(args[leftName]);
  right = wrapLiteral(args[rightName]);

  if (left) {
    if (right) {
      throw new Error("Over-constrained by " + leftName + " and " + rightName);
    } else {
      return left;
    }
  } else {
    if (right) {
      return (segment) => -right(segment);
    } else {
      return () => 0;
    }
  }
}

function pointOnLine(args, leftName, rightName) {
  var left, right;
  left = wrapLiteral(args[leftName]);
  right = wrapLiteral(args[rightName]);

  if (left) {
    if (right) {
      throw new Error("Over-constrained by " + leftName + " and " + rightName);
    } else {
      return (segment, spaceWidth) => left(segment);
    }
  } else {
    if (right) {
      return (segment, spaceWidth) => spaceWidth - right(segment);
    } else {
      return (segment, spaceWidth) => spaceWidth / 2;
    }
  }
}

function lineOnLine(args, leftName, widthName, rightName) {
  var flip, fn, left, right, width;
  left = wrapLiteral(args[leftName]);
  width = wrapLiteral(args[widthName]);
  right = wrapLiteral(args[rightName]);

  if (left && right) {
    if (width) {
      throw new Error("Over-constrained by " + widthName);
    }
    return (segment, spaceWidth) => {
      var leftValue, rightValue;
      leftValue = left(segment);
      rightValue = right(segment);
      if (isInstanceOf(leftValue, Interval) || isInstanceOf(rightValue, Interval)) {
        throw new Error("Over-constrained by interval");
      }
      return [leftValue, spaceWidth - leftValue - rightValue];
    };
  }

  flip = false;
  if (right && !left) {
    left = right;
    leftName = rightName;
    flip = true;
  }

  fn = width ? left ? (segment, spaceWidth) => {
    var leftValue, widthValue;
    leftValue = left(segment);
    if (isInstanceOf(leftValue, Interval)) {
      throw new Error("Over-constrained by " + widthName);
    } else {
      widthValue = width(segment).valueOf();
      return [leftValue, widthValue];
    }
  } : (segment, spaceWidth) => {
    var widthValue;
    widthValue = width(segment).valueOf();
    return [(spaceWidth - widthValue) / 2, widthValue];
  } : left ? (segment, spaceWidth) => {
    var leftValue;
    leftValue = left(segment);
    if (isInstanceOf(leftValue, Interval)) {
      return [leftValue.start, leftValue.end - leftValue.start];
    } else {
      return [leftValue, spaceWidth - leftValue];
    }
  } : (segment, spaceWidth) => [0, spaceWidth];

  if (flip) {
    return (segment, spaceWidth) => {
      var pos;
      pos = fn(segment, spaceWidth);
      pos[0] = spaceWidth - pos[0] - pos[1];
      return pos;
    };
  } else {
    return fn;
  }
}

function lineOnPoint(args, leftName, widthName, rightName) {
  var flip, fn, left, right, width;
  left = wrapLiteral(args[leftName]);
  width = wrapLiteral(args[widthName]);
  right = wrapLiteral(args[rightName]);

  if (left && right) {
    if (width) {
      throw new Error("Over-constrained by " + widthName);
    }
    return (segment, spaceWidth) => {
      var leftValue, rightValue;
      leftValue = left(segment);
      rightValue = right(segment);
      if (isInstanceOf(leftValue, Interval) || isInstanceOf(rightValue, Interval)) {
        throw new Error("Over-constrained by interval");
      }
      return [-leftValue, leftValue + rightValue];
    };
  }

  flip = false;
  if (left && !right) {
    right = left;
    rightName = leftName;
    flip = true;
  }

  fn = (() => {
    if (width) {
      if (right) {
        return (segment) => {
          var rightValue, widthValue;
          rightValue = right(segment);
          if (isInstanceOf(rightValue, Interval)) {
            throw new Error("Over-constrained by " + widthName);
          } else {
            widthValue = width(segment).valueOf();
            return [rightValue, widthValue];
          }
        };
      } else {
        return (segment) => {
          var widthValue;
          widthValue = width(segment).valueOf();
          return [-widthValue / 2, widthValue];
        };
      }
    } else {
      if (right) {
        return (segment) => {
          var rightValue;
          rightValue = right(segment);
          if (isInstanceOf(rightValue, Interval)) {
            return [rightValue.start, rightValue.end - rightValue.start];
          } else {
            return [0, rightValue];
          }
        };
      } else {
        throw new Error("Under-constrained, must have ether " + leftName + ", " + widthName + " or " + rightName);
      }
    }
  })();

  if (flip) {
    return (segment) => {
      var pos;
      pos = fn(segment);
      pos[0] = -pos[0] - pos[1];
      return pos;
    };
  } else {
    return fn;
  }
}

function checkSpace(space, requiredType) {
  if (space.type !== requiredType) {
    throw new Error("Must have a " + requiredType + " space (is " + space.type + ")");
  }
}

module.exports = {
  point: {
    point: (args: any = {}) => {
      var fx, fy;
      fx = pointOnPoint(args, "left", "right");
      fy = pointOnPoint(args, "top", "bottom");

      return (segment, space) => {
        checkSpace(space, "point");

        return {
          type: "point",
          x: fx(segment, space.attr.width),
          y: fy(segment, space.attr.height),
          attr: {}
        };
      };
    },
    line: (args: any = {}) => {
      var fx;
      fx = lineOnPoint(args, "left", "width", "right");

      return (segment, space) => {
        var w, x, _ref;
        checkSpace(space, "point");

        _ref = fx(segment, space.attr.width), x = _ref[0], w = _ref[1];

        return {
          type: "line",
          x: x,
          y: 0,
          attr: {
            length: w
          }
        };
      };
    },
    rectangle: (args: any = {}) => {
      var fx, fy;
      fx = lineOnPoint(args, "left", "width", "right");
      fy = lineOnPoint(args, "top", "height", "bottom");

      return (segment, space) => {
        var h, w, x, y, _ref, _ref1;
        checkSpace(space, "point");

        _ref = fx(segment, space.attr.width), x = _ref[0], w = _ref[1];
        _ref1 = fy(segment, space.attr.height), y = _ref1[0], h = _ref1[1];

        return {
          type: "rectangle",
          x: x,
          y: y,
          attr: {
            width: w,
            height: h
          }
        };
      };
    }
  },
  line: {
    point: () => {
      throw new Error("not implemented yet");
    },
    line: () => {
      throw new Error("not implemented yet");
    },
    rectangle: () => {
      throw new Error("not implemented yet");
    }
  },
  rectangle: {
    point: (args: any = {}) => {
      var fx, fy;
      fx = pointOnLine(args, "left", "right");
      fy = pointOnLine(args, "top", "bottom");

      return (segment, space) => {
        checkSpace(space, "rectangle");

        return {
          type: "point",
          x: fx(segment, space.attr.width),
          y: fy(segment, space.attr.height),
          attr: {}
        };
      };
    },
    line: (args: any = {}) => {
      var direction, fx, fy;
      direction = args.direction;
      if (direction === "vertical") {
        fx = pointOnLine(args, "left", "right");
        fy = lineOnLine(args, "top", "height", "bottom");
      } else {
        fx = lineOnLine(args, "left", "width", "right");
        fy = pointOnLine(args, "top", "bottom");
      }

      return (segment, space) => {
        var a, l, x, y, _ref, _ref1;
        checkSpace(space, "rectangle");

        if (direction === "vertical") {
          x = fx(segment, space.attr.width);
          _ref = fy(segment, space.attr.height), y = _ref[0], l = _ref[1];
          y += l / 2;
          a = 90;
        } else {
          _ref1 = fx(segment, space.attr.width), x = _ref1[0], l = _ref1[1];
          x += l / 2;
          y = fy(segment, space.attr.height);
        }

        return {
          type: "line",
          x: x,
          y: y,
          a: a,
          attr: {
            length: l
          }
        };
      };
    },
    rectangle: (args: any = {}) => {
      var fx, fy;
      fx = lineOnLine(args, "left", "width", "right");
      fy = lineOnLine(args, "top", "height", "bottom");

      return (segment, space) => {
        var h, w, x, y, _ref, _ref1;
        checkSpace(space, "rectangle");

        _ref = fx(segment, space.attr.width), x = _ref[0], w = _ref[1];
        _ref1 = fy(segment, space.attr.height), y = _ref1[0], h = _ref1[1];

        return {
          type: "rectangle",
          x: x,
          y: y,
          attr: {
            width: w,
            height: h
          }
        };
      };
    }
  },
  polygon: {
    point: () => {
      throw new Error("not implemented yet");
    },
    polygon: () => {
      throw new Error("not implemented yet");
    }
  }
};
