"use strict";

import BaseModule = require('./base');
import dummyObject = BaseModule.dummyObject;
import Expression = BaseModule.Expression;
import ExpressionJS = BaseModule.ExpressionJS;
import ExpressionValue = BaseModule.ExpressionValue;
import UnaryExpression = BaseModule.UnaryExpression;

export class BucketExpression extends UnaryExpression {
  static fromJS(parameters: ExpressionJS): BucketExpression {
    return new BucketExpression(UnaryExpression.jsToValue(parameters));
  }

  constructor(parameters: ExpressionValue = {}) {
    super(parameters, dummyObject);
    this._ensureOp("bucket");
  }

  public toString(): string {
    return 'bucket(' + this.operand.toString() + ')';
  }

  public simplify(): Expression {
    return this
  }

  protected _makeFn(operandFn: Function): Function {
    throw new Error("implement me");
  }

  protected _makeFnJS(operandFnJS: string): string {
    throw new Error("implement me");
  }

  // UNARY
}

Expression.classMap["bucket"] = BucketExpression;
