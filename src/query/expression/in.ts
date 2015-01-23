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

export class InExpression extends BinaryExpression {
  static fromJS(parameters: ExpressionJS): InExpression {
    return new InExpression(BinaryExpression.jsToValue(parameters));
  }

  constructor(parameters: ExpressionValue = {}) {
    super(parameters, dummyObject);
    this._ensureOp("in");
  }

  public toString(): string {
    return this.lhs.toString() + ' = ' + this.rhs.toString();
  }

  public simplify(): InExpression {
    return this
  }

  protected _makeFn(lhsFn: Function, rhsFn: Function): Function {
    return (d: any) => lhsFn(d) === rhsFn(d);
  }

  protected _makeFnJS(lhsFnJS: string, rhsFnJS: string): string {
    throw new Error("implement me!");
  }

  // BINARY
}

Expression.classMap["in"] = InExpression;
