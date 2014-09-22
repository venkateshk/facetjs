"use strict";

import Basics = require("../basics") // Prop up
import Lookup = Basics.Lookup;

export function specialJoin(array: string[], sep: string, lastSep: string) {
  var lengthMinus1 = array.length - 1;
  return array.reduce((prev, now, index) => prev + (index < lengthMinus1 ? sep : lastSep) + now);
}

export interface ListIterator<T, TResult> {
  (value: T, index: number, list: T[]): TResult;
}

export function find<T>(array: T[], fn: ListIterator<T, boolean>): T {
  for (var i = 0, len = array.length; i < len; i++) {
    var a = array[i];
    if (fn.call(array, a, i, array)) return a;
  }
  return null;
}

export interface Dummy {}

export var dummyObject: Dummy = {};

export interface AttributeValue extends String {}

