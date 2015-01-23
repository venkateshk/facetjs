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

export class GreaterThanOrEqualsExpression extends BinaryExpression {
  static fromJS(parameters: ExpressionJS): GreaterThanOrEqualsExpression {
    return new GreaterThanOrEqualsExpression(BinaryExpression.jsToValue(parameters));
  }

  constructor(parameters: ExpressionValue = {}) {
    super(parameters, dummyObject);
    this._ensureOp("greaterThanOrEquals");
  }

  public toString(): string {
    return this.lhs.toString() + ' = ' + this.rhs.toString();
  }

  public simplify(): GreaterThanOrEqualsExpression {
    return this
  }

  protected _makeFn(lhsFn: Function, rhsFn: Function): Function {
    return (d: any) => lhsFn(d) >= rhsFn(d);
  }

  protected _makeFnJS(lhsFnJS: string, rhsFnJS: string): string {
    throw '(' + lhsFnJS + '>=' + rhsFnJS + ')';
  }

  // BINARY
}

Expression.classMap["greaterThanOrEquals"] = GreaterThanOrEqualsExpression;
