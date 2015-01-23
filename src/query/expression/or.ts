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

export class OrExpression extends NaryExpression {
  static fromJS(parameters: ExpressionJS): OrExpression {
    return new OrExpression(NaryExpression.jsToValue(parameters));
  }

  constructor(parameters: ExpressionValue = {}) {
    super(parameters, dummyObject);
    this._ensureOp("or");
  }

  public toString(): string {
    return 'or(' + this.operands.map((operand) => operand.toString()) + ')';
  }

  public simplify(): OrExpression {
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

Expression.classMap["or"] = OrExpression;
