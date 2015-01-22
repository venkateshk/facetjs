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

  public simplify(): LessThanExpression {
    return this
  }

  protected _makeFn(lhsFn: Function, rhsFn: Function): Function {
    return (d: any) => lhsFn(d) < rhsFn(d);
  }
}

Expression.classMap["lessThan"] = LessThanExpression;