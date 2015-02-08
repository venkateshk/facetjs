module Core {
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
      this._checkTypeOfOperand('DATASET');
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

    public simplify(): Expression {
      var value = this.valueOf();
      value.operand = this.operand.simplify();
      value.actions = this.actions.map((action) => action.simplify());
      return new ActionsExpression(value);
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

    public substitute(substitutionFn: SubstitutionFn, genDiff: number): Expression {
      var sub = substitutionFn(this, genDiff);
      if (sub) return sub;
      var subOperand = this.operand.substitute(substitutionFn, genDiff);
      var subActions = this.actions.map((action) => action.substitute(substitutionFn, genDiff + 1));
      if (this.operand === subOperand && this.actions.every((action, i) => action === subActions[i])) return this;
      var value = this.valueOf();
      value.operand = subOperand;
      value.actions = subActions;
      return new ActionsExpression(value);
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

    private _performActionsOnNativeDataset(dataset: NativeDataset, context: Lookup<any>): NativeDataset {
      var actions = this.actions;
      if (context) {
        console.log("subs");
        actions = actions.map((action) => {
          return action.substitute((ex: Expression, genDiff: number) => {
            if (genDiff === 0 && ex.isOp('ref') && (<RefExpression>ex).generations === '^') {
              console.log("replace", ex.toJS());
              console.log("with", context[(<RefExpression>ex).name]);
              return new LiteralExpression({ op: 'literal', value: context[(<RefExpression>ex).name] });
            } else {
              return null;
            }
          }, 0); // ToDo: Remove this 0
        });
      }

      for (var i = 0; i < actions.length; i++) {
        var action = actions[i];
        switch (action.action) {
          case 'filter':
            console.log("filter", action.expression.toJS());
            dataset = dataset.filter(action.expression.getFn());
            break;

          case 'apply':
            if (action.expression.isOp('actions')) {
              dataset = dataset.apply((<ApplyAction>action).name, (d: Datum) => {
                return (<ActionsExpression>action.expression).evaluate(d)
              });
            } else {
              dataset = dataset.apply((<ApplyAction>action).name, action.expression.getFn());
            }
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

    public evaluate(context: Lookup<any> = null): Dataset {
      console.log("evaluate", context);
      var operand = this.operand;

      if (operand.isOp('split')) {
        return this._performActionsOnNativeDataset(<NativeDataset>((<LabelExpression>operand).evaluate(context)), context);
      }

      if (operand.isOp('literal')) {
        var ds = <Dataset>(<LiteralExpression>operand).value;
        if (ds.dataset === 'native') {
          return this._performActionsOnNativeDataset(<NativeDataset>ds, context);
        } else {
          throw new Error('can not support that yet (not native)');
        }
      } else {
        throw new Error('can not support that yet (not literal)');
      }
    }

    // UNARY
  }

  Expression.register(ActionsExpression);

}
