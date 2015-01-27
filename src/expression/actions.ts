"use strict";

import ActionModule = require('../action/index');
import Action = ActionModule.Action;

import BaseModule = require('./base');
import dummyObject = BaseModule.dummyObject;
import Expression = BaseModule.Expression;
import ExpressionJS = BaseModule.ExpressionJS;
import ExpressionValue = BaseModule.ExpressionValue;
import UnaryExpression = BaseModule.UnaryExpression;

export class ActionsExpression extends UnaryExpression {
  static fromJS(parameters: ExpressionJS): ActionsExpression {
    var value = UnaryExpression.jsToValue(parameters);
    value.actions = parameters.actions.map(Action.fromJS);
    return new ActionsExpression(value);
  }

  public actions: Action[];

  constructor(parameters: ExpressionValue = {}) {
    super(parameters, dummyObject);
    this._ensureOp("actions");
  }

  public toString(): string {
    return 'actions(' + this.operand.toString() + ')';
  }

  public simplify(): Expression {
    return this
  }

  protected _makeFn(operandFn: Function): Function {
    throw new Error("implement me");
  }

  protected _makeFnJS(operandFnJS: string): string {
    throw new Error("implement me");
  }

  // UNARY
}

Expression.classMap["actions"] = ActionsExpression;
