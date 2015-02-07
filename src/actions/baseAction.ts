/// <reference path="../datatypes/dataset.ts" />
/// <reference path="../expressions/baseExpression.ts" />

module Actions {
  var isInstanceOf = HigherObject.isInstanceOf;

  import ImmutableClass = HigherObject.ImmutableClass;
  import ImmutableInstance = HigherObject.ImmutableInstance;

  import Lookup = Basics.Lookup;
  import Dummy = Basics.Dummy;
  export var dummyObject = Basics.dummyObject;

  // Import from brother modules
  import Expression = Expressions.Expression;
  import ExpressionJS = Expressions.ExpressionJS;
  import SubstitutionFn = Expressions.SubstitutionFn;

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

    static register(act: typeof Action): void {
      var action = (<any>act).name.replace('Action', '').replace(/^\w/, (s: string) => s.toLowerCase());
      Action.classMap[action] = act;
    }

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
      if (!this.expression) return this;
      var value = this.valueOf();
      value.expression = this.expression.simplify();
      return new (Action.classMap[this.action])(value);
    }

    public substitute(substitutionFn: SubstitutionFn, genDiff: number): Action {
      if (!this.expression) return this;
      var subExpression = this.expression.substitute(substitutionFn, genDiff);
      if (this.expression === subExpression) return this;
      var value = this.valueOf();
      value.expression = subExpression;
      return new (Action.classMap[this.action])(value);
    }
  }
  checkAction = Action;
}
