"use strict";

import CommonModule = require("../common");
import specialJoin = CommonModule.specialJoin;
import find = CommonModule.find;
import dummyObject = CommonModule.dummyObject;

import BaseModule = require('./base');
import Expression = BaseModule.Expression;
import ExpressionJS = BaseModule.ExpressionJS;
import ExpressionValue = BaseModule.ExpressionValue;
import BinaryExpression = BaseModule.BinaryExpression;

import LessThanModule = require('./lessThan');
import LessThanExpression = LessThanModule.LessThanExpression;

export class GreaterThanExpression extends BinaryExpression {
  static fromJS(parameters: ExpressionJS): GreaterThanExpression {
    return new GreaterThanExpression(BinaryExpression.jsToValue(parameters));
  }

  constructor(parameters: ExpressionValue = {}) {
    super(parameters, dummyObject);
    this._ensureOp("greaterThan");
  }

  public toString(): string {
    return this.lhs.toString() + ' > ' + this.rhs.toString();
  }

  public simplify(): Expression {
    return new LessThanExpression({
      lhs: this.rhs,
      rhs: this.lhs
    })
  }

  protected _makeFn(lhsFn: Function, rhsFn: Function): Function {
    return (d: any) => lhsFn(d) > rhsFn(d);
  }

  protected _makeFnJS(lhsFnJS: string, rhsFnJS: string): string {
    throw '(' + lhsFnJS + '>' + rhsFnJS + ')';
  }

  // BINARY
}

Expression.classMap["greaterThan"] = GreaterThanExpression;
