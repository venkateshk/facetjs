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

export class EqualsExpression extends BinaryExpression {
  static fromJS(parameters: ExpressionJS): EqualsExpression {
    return new EqualsExpression(BinaryExpression.jsToValue(parameters));
  }

  constructor(parameters: ExpressionValue = {}) {
    super(parameters, dummyObject);
    this._ensureOp("equals");
  }

  public valueOf(): ExpressionValue {
    var value = super.valueOf();
    value.lhs = this.lhs;
    value.rhs = this.rhs;
    return value;
  }

  public toJS(): ExpressionJS {
    var js = super.toJS();
    js.lhs = this.lhs.toJS();
    js.rhs = this.rhs.toJS();
    return js;
  }

  public toString(): string {
    return this.lhs.toString() + ' = ' + this.rhs.toString();
  }

  public simplify(): EqualsExpression {
    return this
  }
}

Expression.classMap["equals"] = EqualsExpression;