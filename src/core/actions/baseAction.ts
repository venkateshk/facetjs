/// <reference path="../datatypes/dataset.ts" />
/// <reference path="../expressions/baseExpression.ts" />

module Core {
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

    static getPrecedenceOrder(action: Action) {
      var orders = [FilterAction, SortAction, LimitAction, DefAction, ApplyAction];

      for (var i = 0; i < orders.length; i++) {
        if (action instanceof orders[i]) return i;
      }
      return orders.length;
    }

    static compare(a: Action, b: Action): number {
      if (Action.getPrecedenceOrder(a) > Action.getPrecedenceOrder(b)) {
        return 1;
      } else if (Action.getPrecedenceOrder(a) < Action.getPrecedenceOrder(b)) {
        return -1;
      }

      var aReferences = a.expression.getReferences();
      var bReferences = b.expression.getReferences();

      if (aReferences.length < bReferences.length) {
        return -1;
      } else if (aReferences.length > bReferences.length) {
        return 1;
      } else {
        if (bReferences.toString() !== aReferences.toString()) {
          return aReferences.toString().localeCompare(bReferences.toString());
        }

        return (<DefAction>a).name.localeCompare((<DefAction>b).name);
      }
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
