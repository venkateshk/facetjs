/// <reference path="../../typings/tsd.d.ts" />
"use strict";

import Basics = require("../basics") // Prop up
import Lookup = Basics.Lookup;

import HigherObjectModule = require("higher-object");
import isInstanceOf = HigherObjectModule.isInstanceOf;
import ImmutableClass = HigherObjectModule.ImmutableClass;
import ImmutableInstance = HigherObjectModule.ImmutableInstance;

import ExpressionModule = require("../expression/index");
import Expression = ExpressionModule.Expression;
import ExpressionJS = ExpressionModule.ExpressionJS;

export interface Dummy {}
export var dummyObject: Dummy = {};

export interface ActionValue {
  action?: string;
  name?: string;
  expression?: Expression;
}

export interface ActionJS {
  action?: string;
  name?: string;
  expression?: ExpressionJS;
}

var check: ImmutableClass<ActionValue, ActionJS>;
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

  constructor(parameters: ActionValue, dummy: Dummy = null) {
    this.action = parameters.action;
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
    return {
      action: this.action
    };
  }

  public toJS(): ActionJS {
    return {
      action: this.action
    };
  }

  public toJSON(): ActionJS {
    return this.toJS();
  }

  public equals(other: Action): boolean {
    return Action.isAction(other) &&
      this.action === other.action
  }

  public getComplexity(): number {
    return 1;
  }

  public simplify(): Action {
    return this;
  }
}
check = Action;


export class DefAction extends Action {
  static fromJS(parameters: ActionJS): DefAction {
    // ToDo:
    // Here Expression is undefined
    return new DefAction({
      action: parameters.action,
      name: parameters.name,
      expression: Expression.fromJS(parameters.expression)
    });
  }

  public name: string;
  public expression: Expression;

  constructor(parameters: ActionValue = {}) {
    super(parameters, dummyObject);
    this.name = parameters.name;
    this.expression = parameters.expression;
    this._ensureAction("def");
  }

  public valueOf(): ActionValue {
    var value = super.valueOf();
    value.name = this.name;
    value.expression = this.expression;
    return value;
  }

  public toJS(): ActionJS {
    var js = super.toJS();
    js.name = this.name;
    js.expression = this.expression.toJS();
    return js;
  }

  public toString(): string {
    return 'DefAction';
  }

  public equals(other: DefAction): boolean {
    return super.equals(other) &&
      this.name === other.name;
  }
}

Action.classMap["def"] = DefAction;
