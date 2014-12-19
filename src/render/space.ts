/// <reference path="../../typings/tsd.d.ts" />
"use strict";

import Basics = require("../basics") // Prop up
import Lookup = Basics.Lookup;

import HigherObjectModule = require("higher-object");
import isInstanceOf = HigherObjectModule.isInstanceOf;
import ImmutableClass = HigherObjectModule.ImmutableClass;
import ImmutableInstance = HigherObjectModule.ImmutableInstance;

export interface Functor {
  (d: any, i: number): number;
}

export function makeFunctor(thing: any): Functor {
  if (thing == null) return thing;
  if (typeof thing === 'function') {
    return <Functor>thing;
  } else {
    return () => thing;
  }
}

function lift(fn: Function): Function {
  return (...args: Functor[]): Functor => {
    return (d: any, i: number) => {
      return <number>fn.apply(this, args.map(((arg: Functor) => arg.call(this, d, i)), this))
    }
  }
}

var add = lift((a: number, b: number) => a + b);
var sub = lift((a: number, b: number, c: number) => a - (b || 0) - (c || 0));
var avg = lift((a: number, b: number) => (a + b) / 2);

function margin1d(left: Functor, width: Functor, right: Functor, parentWidth: Functor): Functor[] {
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

export class Space {
  public parent: Space;
  public x: Functor;
  public y: Functor;

  static isSpace(candidate: any): boolean {
    return isInstanceOf(candidate, Space);
  }

  constructor(parent: Space, x: Functor, y: Functor) {
    this.parent = parent;
    this.x = x;
    this.y = y;
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

export class RectangularSpace extends Space{
  public width: Functor;
  public height: Functor;

  static base(width: number, height: number): RectangularSpace {
    var zero = makeFunctor(0);
    return new RectangularSpace(null, zero, zero, makeFunctor(width), makeFunctor(height));
  }

  constructor(parent: Space, x: Functor, y: Functor, width: Functor, height: Functor) {
    super(parent, x, y);
    this.width = width;
    this.height = height;
  }

  public margin(parameters: MarginParameters) {
    var left = makeFunctor(parameters.left);
    var width = makeFunctor(parameters.width);
    var right = makeFunctor(parameters.right);
    var top = makeFunctor(parameters.top);
    var height = makeFunctor(parameters.height);
    var bottom = makeFunctor(parameters.bottom);

    var xw = margin1d(left, width, right, this.width);
    var yh = margin1d(top, height, bottom, this.height);
    return new RectangularSpace(this, xw[0], yh[0], xw[1], yh[1]);
  }
}
