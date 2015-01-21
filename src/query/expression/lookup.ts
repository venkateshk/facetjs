"use strict";

import CommonModule = require("../common");
import specialJoin = CommonModule.specialJoin;
import find = CommonModule.find;
import dummyObject = CommonModule.dummyObject;

import BaseModule = require('./base');
import Expression = BaseModule.Expression;
import ExpressionJS = BaseModule.ExpressionJS;
import ExpressionValue = BaseModule.ExpressionValue;

export class LookupExpression extends Expression {
  static fromJS(parameters: ExpressionJS): LookupExpression {
    return new LookupExpression(<ExpressionValue>parameters);
  }

  public name: string;

  constructor(parameters: ExpressionValue = {}) {
    super(parameters, dummyObject);
    this.name = parameters.name;
    this._ensureOp("lookup");
    if (typeof this.name !== 'string' || this.name.length === 0) {
      throw new TypeError("must have a nonempty `name`")
    }
  }

  public valueOf(): ExpressionValue {
    var value = super.valueOf();
    value.name = this.name;
    return value;
  }

  public toJS(): ExpressionJS {
    var js = super.toJS();
    js.name = this.name;
    return js;
  }

  public toString(): string {
    return '$' + this.name;
  }

  public equals(other: LookupExpression): boolean {
    return super.equals(other) &&
      this.name === other.name
  }
}

Expression.classMap["lookup"] = LookupExpression;
