"use strict";

import CommonModule = require("../common");
import specialJoin = CommonModule.specialJoin;
import find = CommonModule.find;
import dummyObject = CommonModule.dummyObject;

import BaseModule = require('./base');
import Expression = BaseModule.Expression;
import ExpressionJS = BaseModule.ExpressionJS;
import ExpressionValue = BaseModule.ExpressionValue;
import UnaryExpression = BaseModule.UnaryExpression;

export class AggregateExpression extends UnaryExpression {
  static fromJS(parameters: ExpressionJS): AggregateExpression {
    return new AggregateExpression(UnaryExpression.jsToValue(parameters));
  }

  constructor(parameters: ExpressionValue = {}) {
    super(parameters, dummyObject);
    this._ensureOp("aggregate");
  }

  public toString(): string {
    return 'aggregate(' + this.operand.toString() + ')';
  }

  public simplify(): AggregateExpression {
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

Expression.classMap["aggregate"] = AggregateExpression;
