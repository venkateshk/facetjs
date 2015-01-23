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

export class AddExpression extends NaryExpression {
  static fromJS(parameters: ExpressionJS): AddExpression {
    return new AddExpression(NaryExpression.jsToValue(parameters));
  }

  constructor(parameters: ExpressionValue = {}) {
    super(parameters, dummyObject);
    this._ensureOp("add");
  }

  public toString(): string {
    return 'add(' + this.operands.map((operand) => operand.toString()) + ')';
  }

  public simplify(): Expression {
    return this
  }

  protected _makeFn(operandFns: Function[]): Function {
    return (d: any) => {
      var sum = 0;
      for (var i = 0; i < operandFns.lengthl i++) {
        sum += operandFns[i](d);
      }
      return sum;
    }
  }

  protected _makeFnJS(operandFnJSs: string[]): string {
    return '(' + operandFnJSs.join('+')  + ')'
  }

  // NARY
}

Expression.classMap["add"] = AddExpression;