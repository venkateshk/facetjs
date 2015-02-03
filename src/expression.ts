/// <reference path="../typings/tsd.d.ts" />
"use strict";

import Basics = require("./basics") // Prop up
import Lookup = Basics.Lookup;

import HigherObjectModule = require("higher-object");
import isInstanceOf = HigherObjectModule.isInstanceOf;
import ImmutableClass = HigherObjectModule.ImmutableClass;
import ImmutableInstance = HigherObjectModule.ImmutableInstance;

import Q = require("q");

import DatatypeModule = require("./datatype/index");
import Datum = DatatypeModule.Datum;
import Dataset = DatatypeModule.Dataset;
import NativeDataset = DatatypeModule.NativeDataset;
import NumberRange = DatatypeModule.NumberRange;
import TimeRange = DatatypeModule.TimeRange;

export interface Dummy {}
export var dummyObject: Dummy = {};

export interface ExpressionValue {
  op: string;
  type?: string;
  value?: any;
  name?: string;
  lhs?: Expression;
  rhs?: Expression;
  operand?: Expression;
  operands?: Expression[];
  actions?: Action[];
  regexp?: string;
  fn?: string;
  attribute?: Expression;
}

export interface ExpressionJS {
  op: string;
  type?: string;
  value?: any;
  name?: string;
  lhs?: ExpressionJS;
  rhs?: ExpressionJS;
  operand?: ExpressionJS;
  operands?: ExpressionJS[];
  actions?: ActionJS[];
  regexp?: string;
  fn?: string;
  attribute?: ExpressionJS;
}

// =====================================================================================
// =====================================================================================

var check: ImmutableClass<ExpressionValue, ExpressionJS>;
export class Expression implements ImmutableInstance<ExpressionValue, ExpressionJS> {
  static isExpression(candidate: any): boolean {
    return isInstanceOf(candidate, Expression);
  }

  static facet(input: any = null): Expression {
    if (input) {
      if (typeof input === 'string') {
        return new RefExpression({ op: 'ref', name: input });
      } else {
        return new LiteralExpression({ op: 'literal', value: input });
      }
    } else {
      return new LiteralExpression({
        op: 'literal',
        value: new NativeDataset({ dataset: 'native', data: [{}] })
      });
    }
  }

  static fromJSLoose(param: any): Expression {
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
          expressionJS = { op: 'ref', name: param.substring(1) };
        } else {
          expressionJS = { op: 'literal', value: param };
        }
        break;

      default:
        throw new Error("unrecognizable expression");
    }

    return Expression.fromJS(expressionJS);
  }

  static classMap: Lookup<typeof Expression> = {};
  static fromJS(expressionJS: ExpressionJS): Expression {
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
      this.op === other.op;
  }

  public getComplexity(): number {
    return 1;
  }

  public simplify(): Expression {
    return this;
  }

  public isOp(op: string): boolean {
    return this.op === op;
  }

  public getFn(): Function {
    throw new Error('should never be called directly');
  }

  /* protected */
  public _getRawFnJS(): string {
    throw new Error('should never be called directly');
  }

  public getFnJS(wrap: boolean = true) {
    var rawFnJS = this._getRawFnJS();
    if (wrap) {
      return 'function(d){return ' + rawFnJS + ';}';
    } else {
      return rawFnJS;
    }
  }

  // Action constructors
  protected _performAction(action: Action): Expression {
    return new ActionsExpression({
      op: 'actions',
      operand: this,
      actions: [action]
    });
  }

  /**
   * Apply some expression to the dataset
   *
   * @param name The name of the...
   * @param ex
   * @returns {Expression}
   */
  public apply(name: string, ex: any): Expression {
    if (!Expression.isExpression(ex)) ex = Expression.fromJSLoose(ex);
    return this._performAction(new ApplyAction({ name: name, expression: ex }));
  }

  public filter(ex: any): Expression {
    if (!Expression.isExpression(ex)) ex = Expression.fromJSLoose(ex);
    return this._performAction(new FilterAction({ expression: ex }));
  }

  public sort(ex: any, direction: string): Expression {
    if (!Expression.isExpression(ex)) ex = Expression.fromJSLoose(ex);
    return this._performAction(new SortAction({ expression: ex, direction: direction }));
  }

  public limit(limit: number): Expression {
    return this._performAction(new LimitAction({ limit: limit }));
  }

  // Expression constructors (Unary)
  protected _performUnaryExpression(newValue: ExpressionValue): Expression {
    newValue.operand = this;
    return new (Expression.classMap[newValue.op])(newValue);
  }

  public not() { return this._performUnaryExpression({ op: 'not' }); }
  public match(re: string) { return this._performUnaryExpression({ op: 'match', regexp: re }); }

  // Aggregators
  protected _performAggregate(fn: string, attribute: any): Expression {
    if (attribute && !Expression.isExpression(attribute)) attribute = Expression.fromJSLoose(attribute);
    return this._performUnaryExpression({
      op: 'aggregate',
      fn: fn,
      attribute: attribute
    });
  }

  public count() { return this._performAggregate('count', null); }
  public sum(attr: any) { return this._performAggregate('count', attr); }
  public min(attr: any) { return this._performAggregate('min', attr); }
  public max(attr: any) { return this._performAggregate('max', attr); }
  // ToDo: more...

  // Split
  public split(attribute: any, name: string): Expression {
    if (!Expression.isExpression(attribute)) attribute = Expression.fromJSLoose(attribute);
    return this._performUnaryExpression({
      op: 'split',
      attribute: attribute,
      name: name
    });
  }

  // Expression constructors (Binary)
  protected _performBinaryExpression(newValue: ExpressionValue, otherEx: any): Expression {
    if (!Expression.isExpression(otherEx)) otherEx = Expression.fromJSLoose(otherEx);
    newValue.lhs = this;
    newValue.rhs = otherEx;
    return new (Expression.classMap[newValue.op])(newValue);
  }

  public is(ex: any) { return this._performBinaryExpression({ op: 'is' }, ex); }
  public lessThan(ex: any) { return this._performBinaryExpression({ op: 'lessThan' }, ex); }
  public lessThanOrEqual(ex: any) { return this._performBinaryExpression({ op: 'lessThanOrEqual' }, ex); }
  public greaterThan(ex: any) { return this._performBinaryExpression({ op: 'greaterThan' }, ex); }
  public greaterThanOrEqual(ex: any) { return this._performBinaryExpression({ op: 'greaterThanOrEqual' }, ex); }

  // Expression constructors (Nary)
  protected _performNaryExpression(newValue: ExpressionValue, otherExs: any[]): Expression {
    for (var i = 0; i < otherExs.length; i++) {
      var otherEx = otherExs[i];
      if (Expression.isExpression(otherEx)) continue;
      otherExs[i] = Expression.fromJSLoose(otherEx);
    }
    newValue.operands = [this].concat(otherExs);
    return new (Expression.classMap[newValue.op])(newValue);
  }

  public add(...exs: any[]) { return this._performNaryExpression({ op: 'add' }, exs); }
  public subtract(...exs: any[]) { return this._performNaryExpression({ op: 'subtract' }, exs); }
  public multiply(...exs: any[]) { return this._performNaryExpression({ op: 'multiply' }, exs); }
  public divide(...exs: any[]) { return this._performNaryExpression({ op: 'divide' }, exs); }

  // Compute
  public compute() {
    var deferred: Q.Deferred<Dataset> = <Q.Deferred<Dataset>>Q.defer();
    // ToDo: typecheck2 the expression
    var simple = this.simplify();
    if (simple.isOp('literal')) {
      deferred.resolve((<LiteralExpression>simple).value);
    } else {
      deferred.reject(new Error('can not handle that yet: ' + simple.op));
      // ToDo: implement logic
    }
    return deferred.promise;
  }
}
check = Expression;

// =====================================================================================
// =====================================================================================

export class UnaryExpression extends Expression {
  static jsToValue(parameters: ExpressionJS): ExpressionValue {
    var value: ExpressionValue = {
      op: parameters.op
    };
    if (parameters.operand) {
      value.operand = Expression.fromJSLoose(parameters.operand);
    } else {
      throw new TypeError("must have a operand");
    }

    return value;
  }

  public operand: Expression;

  constructor(parameters: ExpressionValue, dummyObject: Dummy) {
    super(parameters, dummyObject);
    this.operand = parameters.operand;
  }

  public valueOf(): ExpressionValue {
    var value = super.valueOf();
    value.operand = this.operand;
    return value;
  }

  public toJS(): ExpressionJS {
    var js: ExpressionJS = super.toJS();
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

  public simplify(): Expression {
    var simplifiedOperand = this.operand.simplify();

    if (simplifiedOperand.isOp('literal')) {
      return new LiteralExpression({
        op: 'literal',
        value: this._makeFn(simplifiedOperand.getFn())()
      })
    }

    var value = this.valueOf();
    value.operand = simplifiedOperand;
    return new (Expression.classMap[this.op])(value);
  }

  protected _makeFn(operandFn: Function): Function {
    throw new Error("should never be called directly");
  }

  public getFn(): Function {
    return this._makeFn(this.operand.getFn());
  }

  protected _makeFnJS(operandFnJS: string): string {
    throw new Error("should never be called directly");
  }

  /* protected */
  public _getRawFnJS(): string {
    return this._makeFnJS(this.operand._getRawFnJS())
  }
}

// =====================================================================================
// =====================================================================================

export class BinaryExpression extends Expression {
  static jsToValue(parameters: ExpressionJS): ExpressionValue {
    var op = parameters.op;
    var value: ExpressionValue = {
      op: op
    };
    if (parameters.lhs) {
      value.lhs = Expression.fromJSLoose(parameters.lhs);
    } else {
      throw new TypeError("must have a lhs");
    }

    if (parameters.rhs) {
      value.rhs = Expression.fromJSLoose(parameters.rhs);
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
      this.rhs.equals(other.rhs);
  }

  public getComplexity(): number {
    return 1 + this.lhs.getComplexity() + this.rhs.getComplexity()
  }

  public simplify(): Expression {
    var simplifiedLhs = this.lhs.simplify();
    var simplifiedRhs = this.rhs.simplify();

    if (simplifiedLhs.isOp('literal') && simplifiedRhs.isOp('literal')) {
      return new LiteralExpression({
        op: 'literal',
        value: this._makeFn(simplifiedLhs.getFn(), simplifiedRhs.getFn())()
      })
    }

    var value = this.valueOf();
    value.lhs = simplifiedLhs;
    value.rhs = simplifiedRhs;
    return new (Expression.classMap[this.op])(value);
  }

  protected _makeFn(lhsFn: Function, rhsFn: Function): Function {
    throw new Error("should never be called directly");
  }

  public getFn(): Function {
    return this._makeFn(this.lhs.getFn(), this.rhs.getFn());
  }

  protected _makeFnJS(lhsFnJS: string, rhsFnJS: string): string {
    throw new Error("should never be called directly");
  }

  /* protected */
  public _getRawFnJS(): string {
    return this._makeFnJS(this.lhs._getRawFnJS(), this.rhs._getRawFnJS())
  }
}

// =====================================================================================
// =====================================================================================

export class NaryExpression extends Expression {
  static jsToValue(parameters: ExpressionJS): ExpressionValue {
    var op = parameters.op;
    var value: ExpressionValue = {
      op: op
    };
    if (Array.isArray(parameters.operands)) {
      value.operands = parameters.operands.map((operand) => Expression.fromJSLoose(operand));
    } else {
      throw new TypeError("must have a operands");
    }

    return value;
  }

  public operands: Expression[];

  constructor(parameters: ExpressionValue, dummyObject: Dummy) {
    super(parameters, dummyObject);
    this.operands = parameters.operands;
  }

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

  public simplify(): Expression {
    var simplifiedOperands = this.operands.map((operand) => operand.simplify());
    var literalOperands = simplifiedOperands.filter((operand) => operand.isOp('literal'));
    var nonLiteralOperands = simplifiedOperands.filter((operand) => !operand.isOp('literal'));
    var literalExpression = new LiteralExpression({
      op: 'literal',
      value: this._makeFn(literalOperands.map((operand) => operand.getFn()))()
    });

    if (nonLiteralOperands.length) {
      nonLiteralOperands.push(literalExpression);
      var value = this.valueOf();
      value.operands = nonLiteralOperands;
      return new (Expression.classMap[this.op])(value);
    } else {
      return literalExpression
    }
  }

  protected _makeFn(operandFns: Function[]): Function {
    throw new Error("should never be called directly");
  }

  public getFn(): Function {
    return this._makeFn(this.operands.map((operand) => operand.getFn()));
  }

  protected _makeFnJS(operandFnJSs: string[]): string {
    throw new Error("should never be called directly");
  }

  /* protected */
  public _getRawFnJS(): string {
    return this._makeFnJS(this.operands.map((operand) => operand._getRawFnJS()));
  }
}

// =====================================================================================
// =====================================================================================

export class LiteralExpression extends Expression {
  static fromJS(parameters: ExpressionJS): Expression {
    return new LiteralExpression(<any>parameters);
  }

  public value: any;

  constructor(parameters: ExpressionValue) {
    super(parameters, dummyObject);
    var value = parameters.value;
    this.value = value;
    this._ensureOp("literal");
    if (typeof this.value === 'undefined') {
      throw new TypeError("must have a `value`")
    }
    var typeofValue = typeof value;
    if (typeofValue === 'object') {
      if (value === null) {
        this.type = 'NULL';
      } else {
        this.type = value.constructor.type;
        if (!this.type) throw new Error("can not have an object without a type");
      }
    } else {
      this.type = typeofValue.toUpperCase();
    }
    // ToDo: support date!!
  }

  public valueOf(): ExpressionValue {
    var value = super.valueOf();
    value.value = this.value;
    return value;
  }

  public toJS(): ExpressionJS {
    var js = super.toJS();
    if (this.value.toJS) {
      js.value = this.value.toJS();
      js.type = this.type;
    } else {
      js.value = this.value;
    }
    return js;
  }

  public toString(): string {
    return String(this.value);
  }

  public equals(other: LiteralExpression): boolean {
    return super.equals(other) &&
      this.value === other.value;
  }

  public getFn(): Function {
    var value = this.value;
    return () => value;
  }

  public _getRawFnJS(): string {
    return JSON.stringify(this.value); // ToDo: what to do with higher objects?
  }
}

Expression.classMap["literal"] = LiteralExpression;

// =====================================================================================
// =====================================================================================

export class RefExpression extends Expression {
  static fromJS(parameters: ExpressionJS): RefExpression {
    return new RefExpression(<any>parameters);
  }

  public generations: string;
  public name: string;

  constructor(parameters: ExpressionValue) {
    super(parameters, dummyObject);

    var match = parameters.name.match(/^(\^*)([a-z_]\w*)$/i);
    if (match) {
      this.generations = match[1];
      this.name = match[2];
    } else {
      throw new Error("invalid name '" + parameters.name + "'");
    }
    this._ensureOp("ref");
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

  public equals(other: RefExpression): boolean {
    return super.equals(other) &&
      this.name === other.name &&
      this.generations === other.generations;
  }

  public getFn(): Function {
    var len = this.generations.length;
    var name = this.name;
    return (d: Datum) => {
      for (var i = 0; i < len; i++) d = Object.getPrototypeOf(d);
      return d[name];
    }
  }

  public _getRawFnJS(): string {
    var gen = this.generations;
    return gen.replace(/\^/g, "Object.getPrototypeOf(") + 'd.' + this.name + gen.replace(/\^/g, ")");
  }
}

Expression.classMap["ref"] = RefExpression;

// =====================================================================================
// =====================================================================================

export class IsExpression extends BinaryExpression {
  static fromJS(parameters: ExpressionJS): IsExpression {
    return new IsExpression(BinaryExpression.jsToValue(parameters));
  }

  constructor(parameters: ExpressionValue) {
    super(parameters, dummyObject);
    this._ensureOp("is");
    this.type = 'BOOLEAN';
  }

  public toString(): string {
    return this.lhs.toString() + ' = ' + this.rhs.toString();
  }

  public getComplexity(): number {
    return 1 + this.lhs.getComplexity() + this.rhs.getComplexity();
  }

  protected _makeFn(lhsFn: Function, rhsFn: Function): Function {
    return (d: Datum) => lhsFn(d) === rhsFn(d);
  }

  protected _makeFnJS(lhsFnJS: string, rhsFnJS: string): string {
    return '(' + lhsFnJS + '===' + rhsFnJS + ')';
  }

  // BINARY
}

Expression.classMap["is"] = IsExpression;

// =====================================================================================
// =====================================================================================


export class LessThanExpression extends BinaryExpression {
  static fromJS(parameters: ExpressionJS): LessThanExpression {
    return new LessThanExpression(BinaryExpression.jsToValue(parameters));
  }

  constructor(parameters: ExpressionValue) {
    super(parameters, dummyObject);
    this._ensureOp("lessThan");
    this.type = 'BOOLEAN';
  }

  public toString(): string {
    return this.lhs.toString() + ' < ' + this.rhs.toString();
  }

  protected _makeFn(lhsFn: Function, rhsFn: Function): Function {
    return (d: Datum) => lhsFn(d) < rhsFn(d);
  }

  protected _makeFnJS(lhsFnJS: string, rhsFnJS: string): string {
    return '(' + lhsFnJS + '<' + rhsFnJS + ')';
  }

  // BINARY
}

Expression.classMap["lessThan"] = LessThanExpression;
// =====================================================================================
// =====================================================================================


export class LessThanOrEqualExpression extends BinaryExpression {
  static fromJS(parameters: ExpressionJS): LessThanOrEqualExpression {
    return new LessThanOrEqualExpression(BinaryExpression.jsToValue(parameters));
  }

  constructor(parameters: ExpressionValue) {
    super(parameters, dummyObject);
    this._ensureOp("lessThanOrEqual");
    this.type = 'BOOLEAN';
  }

  public toString(): string {
    return this.lhs.toString() + ' <= ' + this.rhs.toString();
  }

  protected _makeFn(lhsFn: Function, rhsFn: Function): Function {
    return (d: Datum) => lhsFn(d) <= rhsFn(d);
  }

  protected _makeFnJS(lhsFnJS: string, rhsFnJS: string): string {
    return '(' + lhsFnJS + '<=' + rhsFnJS + ')';
  }

  // BINARY
}

Expression.classMap["lessThanOrEqual"] = LessThanOrEqualExpression;

// =====================================================================================
// =====================================================================================

export class GreaterThanExpression extends BinaryExpression {
  static fromJS(parameters: ExpressionJS): GreaterThanExpression {
    return new GreaterThanExpression(BinaryExpression.jsToValue(parameters));
  }

  constructor(parameters: ExpressionValue) {
    super(parameters, dummyObject);
    this._ensureOp("greaterThan");
    this.type = 'BOOLEAN';
  }

  public toString(): string {
    return this.lhs.toString() + ' > ' + this.rhs.toString();
  }

  public simplify(): Expression {
    return (new LessThanExpression({
      op: 'lessThan',
      lhs: this.rhs,
      rhs: this.lhs
    })).simplify()
  }

  protected _makeFn(lhsFn: Function, rhsFn: Function): Function {
    return (d: Datum) => lhsFn(d) > rhsFn(d);
  }

  protected _makeFnJS(lhsFnJS: string, rhsFnJS: string): string {
    throw '(' + lhsFnJS + '>' + rhsFnJS + ')';
  }

  // BINARY
}

Expression.classMap["greaterThan"] = GreaterThanExpression;

// =====================================================================================
// =====================================================================================


export class GreaterThanOrEqualExpression extends BinaryExpression {
  static fromJS(parameters: ExpressionJS): GreaterThanOrEqualExpression {
    return new GreaterThanOrEqualExpression(BinaryExpression.jsToValue(parameters));
  }

  constructor(parameters: ExpressionValue) {
    super(parameters, dummyObject);
    this._ensureOp("greaterThanOrEqual");
    this.type = 'BOOLEAN';
  }

  public toString(): string {
    return this.lhs.toString() + ' = ' + this.rhs.toString();
  }

  public simplify(): Expression {
    return (new LessThanOrEqualExpression({
      op: 'lessThanOrEqual',
      lhs: this.rhs,
      rhs: this.lhs
    })).simplify()
  }

  protected _makeFn(lhsFn: Function, rhsFn: Function): Function {
    return (d: Datum) => lhsFn(d) >= rhsFn(d);
  }

  protected _makeFnJS(lhsFnJS: string, rhsFnJS: string): string {
    throw '(' + lhsFnJS + '>=' + rhsFnJS + ')';
  }

  // BINARY
}

Expression.classMap["greaterThanOrEqual"] = GreaterThanOrEqualExpression;

// =====================================================================================
// =====================================================================================


export class InExpression extends BinaryExpression {
  static fromJS(parameters: ExpressionJS): InExpression {
    return new InExpression(BinaryExpression.jsToValue(parameters));
  }

  constructor(parameters: ExpressionValue) {
    super(parameters, dummyObject);
    this._ensureOp("in");
    this.type = 'BOOLEAN';
  }

  public toString(): string {
    return this.lhs.toString() + ' = ' + this.rhs.toString();
  }

  protected _makeFn(lhsFn: Function, rhsFn: Function): Function {
    return (d: Datum) => rhsFn(d).indexOf(lhsFn(d)) > -1;
  }

  protected _makeFnJS(lhsFnJS: string, rhsFnJS: string): string {
    throw new Error("implement me!");
  }

  // BINARY
}

Expression.classMap["in"] = InExpression;

// =====================================================================================
// =====================================================================================


export class MatchExpression extends UnaryExpression {
  static fromJS(parameters: ExpressionJS): MatchExpression {
    var value = UnaryExpression.jsToValue(parameters);
    value.regexp = parameters.regexp;
    return new MatchExpression(value);
  }

  public regexp: string;

  constructor(parameters: ExpressionValue) {
    super(parameters, dummyObject);
    this.regexp = parameters.regexp;
    this._ensureOp("match");
    this.type = 'BOOLEAN';
  }

  public valueOf(): ExpressionValue {
    var value = super.valueOf();
    value.regexp = this.regexp;
    return value;
  }

  public toJS(): ExpressionJS {
    var js = super.toJS();
    js.regexp = this.regexp;
    return js;
  }

  public toString(): string {
    return 'match(' + this.operand.toString() + ', /' + this.regexp + '/)';
  }

  public equals(other: MatchExpression): boolean {
    return super.equals(other) &&
      this.regexp === other.regexp;
  }

  protected _makeFn(operandFn: Function): Function {
    var re = new RegExp(this.regexp);
    return (d: Datum) => re.test(operandFn(d));
  }

  protected _makeFnJS(operandFnJS: string): string {
    return "/" + this.regexp + "/.test(" + operandFnJS + ")";
  }

  // UNARY
}

Expression.classMap["match"] = MatchExpression;

// =====================================================================================
// =====================================================================================

export class NotExpression extends UnaryExpression {
  static fromJS(parameters: ExpressionJS): NotExpression {
    return new NotExpression(UnaryExpression.jsToValue(parameters));
  }

  constructor(parameters: ExpressionValue) {
    super(parameters, dummyObject);
    this._ensureOp("not");
    // ToDo: this._checkOperandType('BOOLEAN');
    this.type = 'BOOLEAN';
  }

  public toString(): string {
    return 'not(' + this.operand.toString() + ')';
  }

  protected _makeFn(operandFn: Function): Function {
    return (d: Datum) => !operandFn(d);
  }

  protected _makeFnJS(operandFnJS: string): string {
    return "!(" + operandFnJS + ")"
  }

  // UNARY
}

Expression.classMap["not"] = NotExpression;

// =====================================================================================
// =====================================================================================

export class NegateExpression extends UnaryExpression {
  static fromJS(parameters: ExpressionJS): NegateExpression {
    return new NegateExpression(UnaryExpression.jsToValue(parameters));
  }

  constructor(parameters: ExpressionValue) {
    super(parameters, dummyObject);
    this._ensureOp("negate");
    this.type = 'NUMBER';
  }

  public toString(): string {
    return 'negate(' + this.operand.toString() + ')';
  }

  protected _makeFn(operandFn: Function): Function {
    return (d: Datum) => -operandFn(d);
  }

  protected _makeFnJS(operandFnJS: string): string {
    return "-(" + operandFnJS + ")"
  }

  // UNARY
}

Expression.classMap["negate"] = NegateExpression;

// =====================================================================================
// =====================================================================================

export class ReciprocalExpression extends UnaryExpression {
  static fromJS(parameters: ExpressionJS): ReciprocalExpression {
    return new ReciprocalExpression(UnaryExpression.jsToValue(parameters));
  }

  constructor(parameters: ExpressionValue) {
    super(parameters, dummyObject);
    this._ensureOp("reciprocal");
    this.type = 'NUMBER';
  }

  public toString(): string {
    return '1/(' + this.operand.toString() + ')';
  }

  protected _makeFn(operandFn: Function): Function {
    return (d: Datum) => 1/operandFn(d);
  }

  protected _makeFnJS(operandFnJS: string): string {
    return "1/(" + operandFnJS + ")"
  }

  // UNARY
}

Expression.classMap["reciprocal"] = ReciprocalExpression;

// =====================================================================================
// =====================================================================================


export class AndExpression extends NaryExpression {
  static fromJS(parameters: ExpressionJS): AndExpression {
    return new AndExpression(NaryExpression.jsToValue(parameters));
  }

  constructor(parameters: ExpressionValue) {
    super(parameters, dummyObject);
    this._ensureOp("and");
    this.type = 'BOOLEAN';
  }

  public toString(): string {
    return 'and(' + this.operands.map((operand) => operand.toString()) + ')';
  }

  public simplify(): Expression {
    return this //TODO
  }

  protected _makeFn(operandFns: Function[]): Function {
    throw new Error("should never be called directly");
  }

  protected _makeFnJS(operandFnJSs: string[]): string {
    throw new Error("should never be called directly");
  }

  // NARY
}

Expression.classMap["and"] = AndExpression;

// =====================================================================================
// =====================================================================================

export class OrExpression extends NaryExpression {
  static fromJS(parameters: ExpressionJS): OrExpression {
    return new OrExpression(NaryExpression.jsToValue(parameters));
  }

  constructor(parameters: ExpressionValue) {
    super(parameters, dummyObject);
    this._ensureOp("or");
    this.type = 'BOOLEAN';
  }

  public toString(): string {
    return '(' + this.operands.map((operand) => operand.toString()).join('or') + ')';
  }

  public simplify(): Expression {
    return this //TODO
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

// =====================================================================================
// =====================================================================================

export class AddExpression extends NaryExpression {
  static fromJS(parameters: ExpressionJS): AddExpression {
    return new AddExpression(NaryExpression.jsToValue(parameters));
  }

  constructor(parameters: ExpressionValue) {
    super(parameters, dummyObject);
    this._ensureOp("add");
    this.type = 'NUMBER';
  }

  public toString(): string {
    return 'add(' + this.operands.map((operand) => operand.toString()) + ')';
  }

  public simplify(): Expression {
    var newOperands: Expression[] = [];
    var literalValue: number = 0;
    for (var i = 0; i < this.operands.length; i++) {
      var simplifiedOperand: Expression = this.operands[i].simplify();
      if (simplifiedOperand.isOp('literal')) {
        literalValue += (<LiteralExpression>simplifiedOperand).value;
      } else {
        newOperands.push(simplifiedOperand);
      }
    }

    if (newOperands.length === 0) {
      return new LiteralExpression({ op: 'literal', value: literalValue });
    } else {
      if (literalValue) {
        newOperands.push(new LiteralExpression({ op: 'literal', value: literalValue }));
      }
      return new AddExpression({
        op: 'add',
        operands: newOperands
      })
    }
  }

  protected _makeFn(operandFns: Function[]): Function {
    return (d: Datum) => {
      var res = 0;
      for (var i = 0; i < operandFns.length; i++) {
        res += operandFns[i](d) || 0;
      }
      return res;
    }
  }

  protected _makeFnJS(operandFnJSs: string[]): string {
    return '(' + operandFnJSs.join('+')  + ')';
  }

  // NARY
}

Expression.classMap["add"] = AddExpression;
// =====================================================================================
// =====================================================================================

export class MultiplyExpression extends NaryExpression {
  static fromJS(parameters: ExpressionJS): MultiplyExpression {
    return new MultiplyExpression(NaryExpression.jsToValue(parameters));
  }

  constructor(parameters: ExpressionValue) {
    super(parameters, dummyObject);
    this._ensureOp("multiply");
    this.type = 'NUMBER';
  }

  public toString(): string {
    return 'multiply(' + this.operands.map((operand) => operand.toString()) + ')';
  }

  protected _makeFn(operandFns: Function[]): Function {
    return (d: Datum) => {
      var res = 1;
      for (var i = 0; i < operandFns.length; i++) {
        res *= operandFns[i](d) || 0;
      }
      return res;
    }
  }

  protected _makeFnJS(operandFnJSs: string[]): string {
    return '(' + operandFnJSs.join('*')  + ')';
  }

  // NARY
}

Expression.classMap["multiply"] = MultiplyExpression;

// =====================================================================================
// =====================================================================================

export class AggregateExpression extends UnaryExpression {
  static fromJS(parameters: ExpressionJS): AggregateExpression {
    var value = UnaryExpression.jsToValue(parameters);
    value.fn = parameters.fn;
    if (parameters.attribute) {
      value.attribute = Expression.fromJSLoose(parameters.attribute);
    }
    return new AggregateExpression(value);
  }

  public fn: string;
  public attribute: Expression;

  constructor(parameters: ExpressionValue) {
    super(parameters, dummyObject);
    this.fn = parameters.fn;
    this.attribute = parameters.attribute;
    this._ensureOp("aggregate");
    // ToDo: add a this._checkOperandType(...) call (everywhere)
    this.type = 'NUMBER'; // For now
    if (this.fn !== 'count' && !this.attribute) {
      throw new Error(this.fn + " aggregate must have an 'attribute'");
    }
  }

  public valueOf(): ExpressionValue {
    var value = super.valueOf();
    value.fn = this.fn;
    if (this.attribute) {
      value.attribute = this.attribute;
    }
    return value;
  }

  public toJS(): ExpressionJS {
    var js = super.toJS();
    js.fn = this.fn;
    if (this.attribute) {
      js.attribute = this.attribute.toJS();
    }
    return js;
  }

  public equals(other: AggregateExpression): boolean {
    return super.equals(other) &&
      this.fn === other.fn &&
      Boolean(this.attribute) === Boolean(other.attribute) &&
      (!this.attribute || this.attribute.equals(other.attribute));
  }

  public toString(): string {
    return 'agg_' + this.fn + '(' + this.operand.toString() + ')';
  }

  public simplify(): Expression {
    return this //TODO
  }

  protected _makeFn(operandFn: Function): Function {
    var fn = this.fn;
    var attributeFn = this.attribute ? this.attribute.getFn() : null;
    return (d: Datum) => operandFn(d)[fn](attributeFn);
  }

  protected _makeFnJS(operandFnJS: string): string {
    throw new Error("implement me");
  }

  // UNARY
}

Expression.classMap["aggregate"] = AggregateExpression;

// =====================================================================================
// =====================================================================================

export class OffsetExpression extends UnaryExpression {
  static fromJS(parameters: ExpressionJS): OffsetExpression {
    return new OffsetExpression(UnaryExpression.jsToValue(parameters));
  }

  constructor(parameters: ExpressionValue) {
    super(parameters, dummyObject);
    this._ensureOp("offset");
    this.type = 'TIME';
  }

  public toString(): string {
    return 'offset(' + this.operand.toString() + ')';
  }

  // ToDo: equals

  public simplify(): Expression {
    return this //ToDo
  }

  protected _makeFn(operandFn: Function): Function {
    throw new Error("implement me");
  }

  protected _makeFnJS(operandFnJS: string): string {
    throw new Error("implement me");
  }

  // UNARY
}

Expression.classMap["offset"] = OffsetExpression;

// =====================================================================================
// =====================================================================================

export class ConcatExpression extends NaryExpression {
  static fromJS(parameters: ExpressionJS): ConcatExpression {
    return new ConcatExpression(NaryExpression.jsToValue(parameters));
  }

  constructor(parameters: ExpressionValue) {
    super(parameters, dummyObject);
    this._ensureOp("concat");
    this.type = 'STRING';
  }

  public toString(): string {
    return 'concat(' + this.operands.map((operand) => operand.toString()) + ')';
  }

  public simplify(): Expression {
    return this //TODO
  }

  protected _makeFn(operandFns: Function[]): Function {
    return (d: Datum) => {
      return operandFns.map((operandFn) => operandFn(d)).join('');
    }
  }

  protected _makeFnJS(operandFnJSs: string[]): string {
    return '(' + operandFnJSs.join('+') + ')';
  }

  // NARY
}

Expression.classMap["concat"] = ConcatExpression;

// =====================================================================================
// =====================================================================================


export class RangeExpression extends BinaryExpression {
  static fromJS(parameters: ExpressionJS): RangeExpression {
    return new RangeExpression(BinaryExpression.jsToValue(parameters));
  }

  constructor(parameters: ExpressionValue) {
    super(parameters, dummyObject);
    this._ensureOp("range");
  }

  public toString(): string {
    return this.lhs.toString() + ' = ' + this.rhs.toString();
  }

  public simplify(): Expression {
    return this //TODO
  }

  protected _makeFn(lhsFn: Function, rhsFn: Function): Function {
    switch (this.type) {
      case 'NUMBER_RANGE':
        return (d: Datum) => new NumberRange({
          start: lhsFn(d),
          end: rhsFn(d)
        });

      case 'TIME_RANGE':
        return (d: Datum) => new TimeRange({
          start: lhsFn(d),
          end: rhsFn(d)
        });

      default:
        throw new Error("must determine type first");
    }
  }

  protected _makeFnJS(lhsFnJS: string, rhsFnJS: string): string {
    throw new Error("implement me!");
  }

  // BINARY
}

Expression.classMap["range"] = RangeExpression;

// =====================================================================================
// =====================================================================================


export class BucketExpression extends UnaryExpression {
  static fromJS(parameters: ExpressionJS): BucketExpression {
    return new BucketExpression(UnaryExpression.jsToValue(parameters));
  }

  constructor(parameters: ExpressionValue) {
    super(parameters, dummyObject);
    this._ensureOp("bucket");
  }

  public toString(): string {
    return 'bucket(' + this.operand.toString() + ')';
  }

  public simplify(): Expression {
    return this //ToDo
  }

  protected _makeFn(operandFn: Function): Function {
    throw new Error("implement me");
  }

  protected _makeFnJS(operandFnJS: string): string {
    throw new Error("implement me");
  }

  // UNARY
}

Expression.classMap["bucket"] = BucketExpression;

// =====================================================================================
// =====================================================================================


export class SplitExpression extends UnaryExpression {
  static fromJS(parameters: ExpressionJS): SplitExpression {
    var value = UnaryExpression.jsToValue(parameters);
    value.attribute = Expression.fromJSLoose(parameters.attribute);
    value.name = parameters.name;
    return new SplitExpression(value);
  }

  public attribute: Expression;
  public name: string;

  constructor(parameters: ExpressionValue) {
    super(parameters, dummyObject);
    this._ensureOp("split");
  }

  public valueOf(): ExpressionValue {
    var value = super.valueOf();
    value.attribute = this.attribute;
    value.name = this.name;
    return value;
  }

  public toJS(): ExpressionJS {
    var js = super.toJS();
    js.attribute = this.attribute.toJS();
    js.name = this.name;
    return js;
  }

  public toString(): string {
    return 'split(' + this.operand.toString() + ')';
  }

  public equals(other: SplitExpression): boolean {
    return super.equals(other) &&
      this.attribute.equals(other.attribute) &&
      this.name === other.name;
  }

  public simplify(): Expression {
    return this //ToDo
  }

  protected _makeFn(operandFn: Function): Function {
    throw new Error("implement me");
  }

  protected _makeFnJS(operandFnJS: string): string {
    throw new Error("implement me");
  }

  // UNARY
}

Expression.classMap["split"] = SplitExpression;

// =====================================================================================
// =====================================================================================

export class ActionsExpression extends UnaryExpression {
  static fromJS(parameters: ExpressionJS): ActionsExpression {
    var value = UnaryExpression.jsToValue(parameters);
    value.actions = parameters.actions.map(Action.fromJS);
    return new ActionsExpression(value);
  }

  public actions: Action[];

  constructor(parameters: ExpressionValue) {
    super(parameters, dummyObject);
    this.actions = parameters.actions;
    this._ensureOp("actions");
    this.type = 'DATASET';
  }

  public valueOf(): ExpressionValue {
    var value = super.valueOf();
    value.actions = this.actions;
    return value;
  }

  public toJS(): ExpressionJS {
    var js = super.toJS();
    js.actions = this.actions.map((action) => action.toJS());
    return js;
  }

  public toString(): string {
    return 'actions(' + this.operand.toString() + ')';
  }

  public equals(other: ActionsExpression): boolean {
    if (!super.equals(other)) return false;
    var thisActions = this.actions;
    var otherActions = other.actions;
    if (thisActions.length !== otherActions.length) return false;
    for (var i = 0; i < thisActions.length; i++) {
      if (!thisActions[i].equals(otherActions[i])) return false;
    }
    return true;
  }

  public simplify(): Expression {
    return this //TODO
  }

  protected _makeFn(operandFn: Function): Function {
    var actions = this.actions;
    return (d: Datum) => {
      var dataset = operandFn(d);
      for (var i = 0; i < actions.length; i++) {
        var action = actions[i];
        switch (action.action) {
          case 'filter':
            dataset = dataset.filter(action.expression.getFn());
            break;

          case 'apply':
            dataset = dataset.apply((<ApplyAction>action).name, action.expression.getFn());
            break;

          case 'sort':
            dataset = dataset.sort(action.expression.getFn(), (<SortAction>action).direction);
            break;

          case 'limit':
            dataset = dataset.limit((<LimitAction>action).limit);
            break;
        }
      }
      return dataset;
    }
  }

  protected _makeFnJS(operandFnJS: string): string {
    throw new Error("implement me");
  }

  protected _performAction(action: Action): Expression {
    return new ActionsExpression({
      op: 'actions',
      operand: this.operand,
      actions: this.actions.concat(action)
    });
  }

  // UNARY
}

Expression.classMap["actions"] = ActionsExpression;

// =====================================================================================
// =====================================================================================

export interface ActionValue {
  action?: string;
  name?: string;
  expression?: Expression;
  direction?: string;
  limit?: number;
}

export interface ActionJS {
  action?: string;
  name?: string;
  expression?: ExpressionJS;
  direction?: string;
  limit?: number;
}

// =====================================================================================
// =====================================================================================

var checkAction: ImmutableClass<ActionValue, ActionJS>;
export class Action implements ImmutableInstance<ActionValue, ActionJS> {
  static isAction(candidate: any): boolean {
    return isInstanceOf(candidate, Action);
  }

  static classMap: Lookup<typeof Action> = {};
  static fromJS(actionJS: ActionJS): Action {
    if (!actionJS.hasOwnProperty("action")) {
      throw new Error("action must be defined");
    }
    var action = actionJS.action;
    if (typeof action !== "string") {
      throw new Error("action must be a string");
    }
    var ClassFn = Action.classMap[action];
    if (!ClassFn) {
      throw new Error("unsupported action '" + action + "'");
    }

    return ClassFn.fromJS(actionJS);
  }

  public action: string;
  public expression: Expression;

  constructor(parameters: ActionValue, dummy: Dummy = null) {
    this.action = parameters.action;
    this.expression = parameters.expression;
    if (dummy !== dummyObject) {
      throw new TypeError("can not call `new Action` directly use Action.fromJS instead");
    }
  }

  protected _ensureAction(action: string) {
    if (!this.action) {
      this.action = action;
      return;
    }
    if (this.action !== action) {
      throw new TypeError("incorrect action '" + this.action + "' (needs to be: '" + action + "')");
    }
  }

  public valueOf(): ActionValue {
    var value: ActionValue = {
      action: this.action
    };
    if (this.expression) {
      value.expression = this.expression;
    }
    return value;
  }

  public toJS(): ActionJS {
    var js: ActionJS = {
      action: this.action
    };
    if (this.expression) {
      js.expression = this.expression.toJS();
    }
    return js;
  }

  public toJSON(): ActionJS {
    return this.toJS();
  }

  public equals(other: Action): boolean {
    return Action.isAction(other) &&
      this.action === other.action
  }

  public getComplexity(): number {
    return 1 + (this.expression ? this.expression.getComplexity() : 0);
  }

  public simplify(): Action {
    return this;
  }
}
checkAction = Action;

// =====================================================================================
// =====================================================================================

export class ApplyAction extends Action {
  static fromJS(parameters: ActionJS): ApplyAction {
    return new ApplyAction({
      action: parameters.action,
      name: parameters.name,
      expression: Expression.fromJS(parameters.expression)
    });
  }

  public name: string;

  constructor(parameters: ActionValue = {}) {
    super(parameters, dummyObject);
    this.name = parameters.name;
    this._ensureAction("apply");
  }

  public valueOf(): ActionValue {
    var value = super.valueOf();
    value.name = this.name;
    return value;
  }

  public toJS(): ActionJS {
    var js = super.toJS();
    js.name = this.name;
    return js;
  }

  public toString(): string {
    return 'Apply(' + this.name + ', ' + this.expression.toString() + ')';
  }

  public equals(other: ApplyAction): boolean {
    return super.equals(other) &&
      this.name === other.name;
  }
}

Action.classMap["apply"] = ApplyAction;

// =====================================================================================
// =====================================================================================

export class FilterAction extends Action {
  static fromJS(parameters: ActionJS): FilterAction {
    return new FilterAction({
      action: parameters.action,
      name: parameters.name,
      expression: Expression.fromJS(parameters.expression)
    });
  }

  constructor(parameters: ActionValue = {}) {
    super(parameters, dummyObject);
    this._ensureAction("filter");
  }

  public toString(): string {
    return 'Filter(' + this.expression.toString() + ')';
  }
}

Action.classMap["filter"] = FilterAction;

// =====================================================================================
// =====================================================================================

export class SortAction extends Action {
  static fromJS(parameters: ActionJS): SortAction {
    return new SortAction({
      action: parameters.action,
      expression: Expression.fromJS(parameters.expression),
      direction: parameters.direction
    });
  }

  public direction: string;

  constructor(parameters: ActionValue = {}) {
    super(parameters, dummyObject);
    this.direction = parameters.direction;
    this._ensureAction("sort");
    if (this.direction !== 'descending' && this.direction !== 'ascending') {
      throw new Error("direction must be 'descending' or 'ascending'");
    }
  }

  public valueOf(): ActionValue {
    var value = super.valueOf();
    value.direction = this.direction;
    return value;
  }

  public toJS(): ActionJS {
    var js = super.toJS();
    js.direction = this.direction;
    return js;
  }

  public toString(): string {
    return 'Sort(' + this.expression.toString() + ', ' + this.direction + ')';
  }

  public equals(other: SortAction): boolean {
    return super.equals(other) &&
      this.direction === other.direction;
  }
}

Action.classMap["sort"] = SortAction;

// =====================================================================================
// =====================================================================================

export class LimitAction extends Action {
  static fromJS(parameters: ActionJS): LimitAction {
    return new LimitAction({
      action: parameters.action,
      limit: parameters.limit
    });
  }

  public limit: number;

  constructor(parameters: ActionValue = {}) {
    super(parameters, dummyObject);
    this.limit = parameters.limit;
    this._ensureAction("limit");
  }

  public valueOf(): ActionValue {
    var value = super.valueOf();
    value.limit = this.limit;
    return value;
  }

  public toJS(): ActionJS {
    var js = super.toJS();
    js.limit = this.limit;
    return js;
  }

  public toString(): string {
    return 'Limit(' + this.limit + ')';
  }

  public equals(other: LimitAction): boolean {
    return super.equals(other) &&
      this.limit === other.limit;
  }
}

Action.classMap["limit"] = LimitAction;
