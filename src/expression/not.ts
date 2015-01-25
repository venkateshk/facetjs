"use strict";

import BaseModule = require('./base');
import dummyObject = BaseModule.dummyObject;
import Expression = BaseModule.Expression;
import ExpressionJS = BaseModule.ExpressionJS;
import ExpressionValue = BaseModule.ExpressionValue;
import UnaryExpression = BaseModule.UnaryExpression;

export class NotExpression extends UnaryExpression {
  static fromJS(parameters: ExpressionJS): NotExpression {
    return new NotExpression(UnaryExpression.jsToValue(parameters));
  }

  constructor(parameters: ExpressionValue = {}) {
    super(parameters, dummyObject);
    this._ensureOp("not");
  }

  public toString(): string {
    return 'not(' + this.operand.toString() + ')';
  }

  public simplify(): Expression {
    return this
  }

  protected _makeFn(operandFn: Function): Function {
    return (d: any) => !operandFn(d);
  }

  protected _makeFnJS(operandFnJS: string): string {
    return "!(" + operandFnJS + ")"
  }

  // UNARY
}

Expression.classMap["not"] = NotExpression;