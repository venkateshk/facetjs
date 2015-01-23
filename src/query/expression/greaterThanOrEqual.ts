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

import LessThanOrEqualModule = require('./lessThanOrEqual');
import LessThanOrEqualExpression = LessThanOrEqualModule.LessThanOrEqualExpression;

export class GreaterThanOrEqualExpression extends BinaryExpression {
  static fromJS(parameters: ExpressionJS): GreaterThanOrEqualExpression {
    return new GreaterThanOrEqualExpression(BinaryExpression.jsToValue(parameters));
  }

  constructor(parameters: ExpressionValue = {}) {
    super(parameters, dummyObject);
    this._ensureOp("greaterThanOrEqual");
  }

  public toString(): string {
    return this.lhs.toString() + ' = ' + this.rhs.toString();
  }

  public simplify(): Expression {
    return new LessThanOrEqualExpression({
      lhs: this.rhs,
      rhs: this.lhs
    })
  }

  protected _makeFn(lhsFn: Function, rhsFn: Function): Function {
    return (d: any) => lhsFn(d) >= rhsFn(d);
  }

  protected _makeFnJS(lhsFnJS: string, rhsFnJS: string): string {
    throw '(' + lhsFnJS + '>=' + rhsFnJS + ')';
  }

  // BINARY
}

Expression.classMap["greaterThanOrEqual"] = GreaterThanOrEqualExpression;
