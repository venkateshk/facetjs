/// <reference path="../../typings/tsd.d.ts" />
"use strict";

import Basics = require("../basics") // Prop up
import Lookup = Basics.Lookup;

import HigherObjectModule = require("higher-object");
import isInstanceOf = HigherObjectModule.isInstanceOf;
import ImmutableClass = HigherObjectModule.ImmutableClass;
import ImmutableInstance = HigherObjectModule.ImmutableInstance;

function lift(fn: Function): any {
  if ('function' !== typeof fn) throw new TypeError();

  return function(/* args: to fn */) {
    var args = Array.prototype.slice.call(arguments),
      n = args.length;

    for (var i = 0; i < n; i++) {
      if ('function' === typeof args[i]) {
        return function(/* args2 to function wrapper */) {
          var args2 = Array.prototype.slice.call(arguments),
            reduced: any[] = [];

          for (var i = 0; i < n; i++) {
            var v = args[i];
            reduced.push('function' === typeof v ? v.apply(this, args2) : v);
          }

          return fn.apply(null, reduced);
        };
      }
    }

    // Fell through so there are no functions in the arguments to fn -> call it!
    return fn.apply(null, args);
  };
}

var add = lift((a: number, b: number) => a + b);
var sub = lift((a: number, b: number, c: number) => a - (b || 0) - (c || 0));
var avg = lift((a: number, b: number) => (a + b) / 2);

function margin1d(left: any, width: any, right: any, parentWidth: any): any[] {
  if (left != null) {
    if (width != null) {
      if (right != null) throw new Error("over-constrained");
      return [left, width];
    } else {
      return [left, sub(parentWidth, left, right)];
    }
  } else {
    if (width != null) {
      if (right != null) {
        return [sub(parentWidth, width, right), width];
      } else {
        return [avg(parentWidth, width), width];
      }
    } else {
      return [0, sub(parentWidth, right)];
    }
  }
}

export interface ShapeJS {
  x: any;
  y: any;
  width?: any;
  height?: any;
}

export class Shape {
  public parent: Shape;
  public x: any;
  public y: any;

  static rectangle(width: number, height: number): RectangularShape {
    return new RectangularShape(null, 0, 0, width, height);
  }

  static isShape(candidate: any): boolean {
    return isInstanceOf(candidate, Shape);
  }

  constructor(parent: Shape, x: any, y: any) {
    this.parent = parent;
    this.x = x;
    this.y = y;
  }

  public isLiteral(): boolean {
    return typeof this.x !== 'function' && typeof this.y !== 'function';
  }

  public toJS(): ShapeJS {
    return {
      x: this.x,
      y: this.y
    };
  }

  public evaluate(stat: any): Shape { // Stat
    return this;
  }
}

export interface MarginParameters {
  left: any;
  width: any;
  right: any;
  top: any;
  height: any;
  bottom: any;
}

export class RectangularShape extends Shape {
  public width: any;
  public height: any;

  static base(width: number, height: number): RectangularShape {
    return new RectangularShape(null, 0, 0, width, height);
  }

  constructor(parent: Shape, x: any, y: any, width: any, height: any) {
    super(parent, x, y);
    this.width = width;
    this.height = height;
  }

  public isLiteral(): boolean {
    return super.isLiteral() && typeof this.width !== 'function' && typeof this.height !== 'function';
  }

  public toJS(): ShapeJS {
    var js = super.toJS();
    js.width = this.width;
    js.height = this.height;
    return js;
  }

  public margin(parameters: MarginParameters) {
    var left = parameters.left;
    var width = parameters.width;
    var right = parameters.right;
    var top = parameters.top;
    var height = parameters.height;
    var bottom = parameters.bottom;

    var xw = margin1d(left, width, right, this.width);
    var yh = margin1d(top, height, bottom, this.height);
    return new RectangularShape(this, xw[0], yh[0], xw[1], yh[1]);
  }
}
