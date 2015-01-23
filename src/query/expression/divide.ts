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

export class DivideExpression extends NaryExpression {
  static fromJS(parameters: ExpressionJS): DivideExpression {
    return new DivideExpression(NaryExpression.jsToValue(parameters));
  }

  constructor(parameters: ExpressionValue = {}) {
    super(parameters, dummyObject);
    this._ensureOp("divide");
  }

  public toString(): string {
    return 'divide(' + this.operands.map((operand) => operand.toString()) + ')';
  }

  public simplify(): DivideExpression {
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

Expression.classMap["divide"] = DivideExpression;
