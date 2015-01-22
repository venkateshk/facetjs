/// <reference path="../../../typings/tsd.d.ts" />
"use strict";

import Basics = require("../../basics") // Prop up
import Lookup = Basics.Lookup;

import HigherObjectModule = require("higher-object");
import isInstanceOf = HigherObjectModule.isInstanceOf;
import ImmutableClass = HigherObjectModule.ImmutableClass;
import ImmutableInstance = HigherObjectModule.ImmutableInstance;

import CommonModule = require("../common");
import specialJoin = CommonModule.specialJoin;
import find = CommonModule.find;
import dummyObject = CommonModule.dummyObject;
import Dummy = CommonModule.Dummy;

export interface ExpressionJS {
  op?: string;
  attribute?: string;
  value?: any;
  name?: string;
  lhs?: ExpressionJS;
  rhs?: ExpressionJS;
  operand?: ExpressionJS;
  operands?: ExpressionJS[];
}

export interface ExpressionValue {
  op?: string;
  attribute?: string;
  value?: any;
  name?: string;
  lhs?: Expression;
  rhs?: Expression;
  operand?: Expression;
  operands?: Expression[];
}

var check: ImmutableClass<ExpressionValue, ExpressionJS>;
export class Expression implements ImmutableInstance<ExpressionValue, ExpressionJS> {
  static isExpression(candidate: any): boolean {
    return isInstanceOf(candidate, Expression);
  }

  static classMap: Lookup<typeof Expression> = {};
  static fromJS(expressionJS: string): Expression;
  static fromJS(expressionJS: ExpressionJS): Expression;
  static fromJS(param: any): Expression {
    var expressionJS: ExpressionJS;
    // Quick parse simple expressions
    switch (typeof param) {
      case 'object':
        expressionJS = <ExpressionJS>param;
        break;

      case 'number':
        expressionJS = { op: 'literal', value: param };
        break;

      case 'string':
        if (param[0] === '$') {
          expressionJS = { op: 'lookup', name: param.substring(1) };
        } else {
          expressionJS = { op: 'literal', value: param };
        }
        break;

      default:
        throw new Error("unrecognizable expression");
    }
    if (!expressionJS.hasOwnProperty("op")) {
      throw new Error("op must be defined");
    }
    var op = expressionJS.op;
    if (typeof op !== "string") {
      throw new Error("op must be a string");
    }
    var ClassFn = Expression.classMap[op];
    if (!ClassFn) {
      throw new Error("unsupported expression op '" + op + "'");
    }

    return ClassFn.fromJS(expressionJS);
  }

  public op: string;
  public type: string;

  constructor(parameters: ExpressionValue, dummy: Dummy = null) {
    this.op = parameters.op;
    if (dummy !== dummyObject) {
      throw new TypeError("can not call `new Expression` directly use Expression.fromJS instead");
    }
  }

  protected _ensureOp(op: string) {
    if (!this.op) {
      this.op = op;
      return;
    }
    if (this.op !== op) {
      throw new TypeError("incorrect expression op '" + this.op + "' (needs to be: '" + op + "')");
    }
  }

  public valueOf(): ExpressionValue {
    return {
      op: this.op
    };
  }

  public toJS(): ExpressionJS {
    return {
      op: this.op
    };
  }

  public toJSON(): ExpressionJS {
    return this.toJS();
  }

  public equals(other: Expression): boolean {
    return Expression.isExpression(other) &&
      this.op === other.op
  }

  public getComplexity(): number {
    return 1;
  }

  public simplify(): Expression {
    return this;
  }

  public getFn(): Function {
    throw new Error('should never be called directly');
  }
}
check = Expression;


export class UnaryExpression extends Expression {
  static jsToValue(parameters: ExpressionJS): ExpressionValue {
    var op = parameters.op;
    var value: ExpressionValue = {
      op: op
    };
    if (parameters.operand) {
      value.operand = Expression.fromJS(parameters.operand);
    } else {
      throw new TypeError("must have a operand");
    }

    return value;
  }

  public operand: Expression;

  public valueOf(): ExpressionValue {
    var value = super.valueOf();
    value.operand = this.operand;
    return value;
  }

  public toJS(): ExpressionJS {
    var js = super.toJS();
    js.operand = this.operand.toJS();
    return js;
  }

  public equals(other: UnaryExpression): boolean {
    return super.equals(other) &&
      this.operand.equals(other.operand)
  }

  public getComplexity(): number {
    return 1 + this.operand.getComplexity()
  }
}

export class BinaryExpression extends Expression {
  static jsToValue(parameters: ExpressionJS): ExpressionValue {
    var op = parameters.op;
    var value: ExpressionValue = {
      op: op
    };
    if (parameters.lhs) {
      value.lhs = Expression.fromJS(parameters.lhs);
    } else {
      throw new TypeError("must have a lhs");
    }

    if (parameters.rhs) {
      value.rhs = Expression.fromJS(parameters.rhs);
    } else {
      throw new TypeError("must have a rhs");
    }

    return value;
  }

  public lhs: Expression;
  public rhs: Expression;

  protected simple: boolean;

  constructor(parameters: ExpressionValue, dummyObject: Dummy) {
    super(parameters, dummyObject);
    this.lhs = parameters.lhs;
    this.rhs = parameters.rhs;
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

  public equals(other: BinaryExpression): boolean {
    return super.equals(other) &&
      this.lhs.equals(other.lhs) &&
      this.rhs.equals(other.rhs)
  }

  public getComplexity(): number {
    return 1 + this.lhs.getComplexity() + this.rhs.getComplexity()
  }
}

export class NaryExpression extends Expression {
  static jsToValue(parameters: ExpressionJS): ExpressionValue {
    var op = parameters.op;
    var value: ExpressionValue = {
      op: op
    };
    if (Array.isArray(parameters.operands)) {
      value.operands = parameters.operands.map((operand) => Expression.fromJS(operand));
    } else {
      throw new TypeError("must have a operands");
    }

    return value;
  }

  public operands: Expression[];

  public valueOf(): ExpressionValue {
    var value = super.valueOf();
    value.operands = this.operands;
    return value;
  }

  public toJS(): ExpressionJS {
    var js = super.toJS();
    js.operands = this.operands.map((operand) => operand.toJS());
    return js;
  }

  public equals(other: NaryExpression): boolean {
    if (!(super.equals(other) && this.operands.length === other.operands.length)) return false;
    var thisOperands = this.operands;
    var otherOperands = other.operands;
    for (var i = 0; i < thisOperands.length; i++) {
      if (!thisOperands[i].equals(otherOperands[i])) return false;
    }
    return true;
  }

  public getComplexity(): number {
    var complexity = 1;
    var operands = this.operands;
    for (var i = 0; i < operands.length; i++) {
      complexity += operands[i].getComplexity();
    }
    return complexity;
  }
}
