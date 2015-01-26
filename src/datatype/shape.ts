/// <reference path="../../typings/tsd.d.ts" />
"use strict";

import Basics = require("../basics") // Prop up
import Lookup = Basics.Lookup;

import HigherObjectModule = require("higher-object");
import isInstanceOf = HigherObjectModule.isInstanceOf;
import ImmutableClass = HigherObjectModule.ImmutableClass;
import ImmutableInstance = HigherObjectModule.ImmutableInstance;

function margin1d(left: any, width: any, right: any, parentWidth: any): any[] {
  if (left != null) {
    if (width != null) {
      if (right != null) throw new Error("over-constrained");
      return [left, width];
    } else {
      return [left, parentWidth - left - (right || 0)];
    }
  } else {
    if (width != null) {
      if (right != null) {
        return [parentWidth - width - right, width];
      } else {
        return [(parentWidth + width) / 2, width];
      }
    } else {
      return [0, parentWidth - right];
    }
  }
}

export interface ShapeJS {
  shape: string;
  x: number;
  y: number;
  width?: number;
  height?: number;
}

var check: ImmutableClass<ShapeJS, ShapeJS>;
export class Shape implements ImmutableInstance<ShapeJS, ShapeJS> {
  static rectangle(width: number, height: number): RectangularShape {
    return new RectangularShape(0, 0, width, height);
  }


  static fromJS(paramaters: ShapeJS): Shape {

  }

  static isShape(candidate: any): boolean {
    return isInstanceOf(candidate, Shape);
  }

  public x: any;
  public y: any;

  constructor(x: any, y: any) {
    this.x = x;
    this.y = y;
  }

  public toJS(): ShapeJS {
    return {
      x: this.x,
      y: this.y
    };
  }
}
check = Shape;

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
    return new RectangularShape(0, 0, width, height);
  }

  constructor(x: any, y: any, width: any, height: any) {
    super(x, y);
    this.width = width;
    this.height = height;
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
    return new RectangularShape(xw[0], yh[0], xw[1], yh[1]);
  }
}
