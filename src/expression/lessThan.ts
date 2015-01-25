"use strict";

import BaseModule = require('./base');
import dummyObject = BaseModule.dummyObject;
import Expression = BaseModule.Expression;
import ExpressionJS = BaseModule.ExpressionJS;
import ExpressionValue = BaseModule.ExpressionValue;
import BinaryExpression = BaseModule.BinaryExpression;

export class LessThanExpression extends BinaryExpression {
  static fromJS(parameters: ExpressionJS): LessThanExpression {
    return new LessThanExpression(BinaryExpression.jsToValue(parameters));
  }

  constructor(parameters: ExpressionValue = {}) {
    super(parameters, dummyObject);
    this._ensureOp("lessThan");
  }

  public toString(): string {
    return this.lhs.toString() + ' < ' + this.rhs.toString();
  }

  public simplify(): Expression {
    return this
  }

  protected _makeFn(lhsFn: Function, rhsFn: Function): Function {
    return (d: any) => lhsFn(d) < rhsFn(d);
  }

  protected _makeFnJS(lhsFnJS: string, rhsFnJS: string): string {
    throw new Error("implement me!");
  }

  // BINARY
}

Expression.classMap["lessThan"] = LessThanExpression;