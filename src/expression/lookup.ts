"use strict";

import BaseModule = require('./base');
import dummyObject = BaseModule.dummyObject;
import Expression = BaseModule.Expression;
import ExpressionJS = BaseModule.ExpressionJS;
import ExpressionValue = BaseModule.ExpressionValue;

export class LookupExpression extends Expression {
  static fromJS(parameters: ExpressionJS): LookupExpression {
    return new LookupExpression(<ExpressionValue>parameters);
  }

  public generations: string;
  public name: string;

  constructor(parameters: ExpressionValue = {}) {
    super(parameters, dummyObject);
    var match = parameters.name.match(/^(\^*)([a-z_]\w+)$/i);
    if (match) {
      this.generations = match[1];
      this.name = match[2];
    } else {
      throw new Error("invalid name '" + parameters.name + "'");
    }
    this._ensureOp("lookup");
    if (typeof this.name !== 'string' || this.name.length === 0) {
      throw new TypeError("must have a nonempty `name`");
    }
  }

  public valueOf(): ExpressionValue {
    var value = super.valueOf();
    value.name = this.generations + this.name;
    return value;
  }

  public toJS(): ExpressionJS {
    var js = super.toJS();
    js.name = this.generations + this.name;
    return js;
  }

  public toString(): string {
    return '$' + this.generations + this.name;
  }

  public equals(other: LookupExpression): boolean {
    return super.equals(other) &&
      this.name === other.name &&
      this.generations === other.generations;
  }

  public getFn(): Function {
    var len = this.generations.length;
    var name = this.name;
    return (d: any) => {
      for (var i = 0; i < len; i++) d = Object.getPrototypeOf(d);
      return d[name];
    }
  }

  public _getRawFnJS(): string {
    var gen = this.generations;
    return gen.replace(/\^/g, "Object.getPrototypeOf(") + 'd.' + this.name + gen.replace(/\^/g, ")");
  }
}

Expression.classMap["lookup"] = LookupExpression;
