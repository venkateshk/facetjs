"use strict";

import CommonModule = require("../common");
import specialJoin = CommonModule.specialJoin;
import find = CommonModule.find;
import dummyObject = CommonModule.dummyObject;

import BaseModule = require('./base');
import Expression = BaseModule.Expression;
import ExpressionJS = BaseModule.ExpressionJS;
import ExpressionValue = BaseModule.ExpressionValue;
import NaryExpression = BaseModule.NaryExpression;

export class MultiplyExpression extends NaryExpression {
  static fromJS(parameters: ExpressionJS): MultiplyExpression {
    return new MultiplyExpression(NaryExpression.jsToValue(parameters));
  }

  constructor(parameters: ExpressionValue = {}) {
    super(parameters, dummyObject);
    this._ensureOp("multiply");
  }

  public toString(): string {
    return 'multiply(' + this.operands.map((operand) => operand.toString()) + ')';
  }

  public simplify(): Expression {
    return this
  }

  protected _makeFn(operandFns: Function[]): Function {
    throw new Error("should never be called directly");
  }

  protected _makeFnJS(operandFnJSs: string[]): string {
    throw new Error("should never be called directly");
  }

  // NARY
}

Expression.classMap["multiply"] = MultiplyExpression;
