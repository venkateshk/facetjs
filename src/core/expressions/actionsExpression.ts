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
      var alphabeticallySortedActions: Action[];
      var aReferences: string[];
      var bReferences: string[];
      var filters: FilterAction[];
      var previousSortAction: SortAction;
      var referenceMap: { [k: string]: number };
      var references: string[];
      var rootNode: Action;
      var rootNodes: Action[];
      var seen: { [k: string]: boolean };
      var simplifiedActions: Action[];
      var sortLimitMap: { [k: string]: LimitAction};
      var thisAction: Action;
      var topologicallySortedActions: Action[];

      var value = this.valueOf();
      value.operand = this.operand.simplify();
      value.actions = [];

      simplifiedActions = this.actions.slice();
      filters = simplifiedActions.filter((action) => action instanceof FilterAction);
      if (filters.length > 0) { // merge filters
        simplifiedActions = simplifiedActions.filter((action) => !(action instanceof FilterAction));
        simplifiedActions.push(new FilterAction({
          expression: new AndExpression({
            op: 'and',
            operands: filters.map((filterAction) => filterAction.expression)
          })
        }));
      }
      simplifiedActions = simplifiedActions.map((action) => action.simplify());
      alphabeticallySortedActions = simplifiedActions.filter((action) => !(action instanceof LimitAction))

      sortLimitMap = {};
      for (var i = 0; i < simplifiedActions.length; i++) {
        if (simplifiedActions[i] instanceof SortAction) previousSortAction = <SortAction>simplifiedActions[i];

        if ((simplifiedActions[i] instanceof LimitAction) && previousSortAction) {
          sortLimitMap[previousSortAction.toString()] = <LimitAction>simplifiedActions[i];
          previousSortAction = undefined;
        }
      }

      // Sort topologically
      seen = {};
      referenceMap = {};
      for (var i = 0; i < alphabeticallySortedActions.length; i++) {
        thisAction = alphabeticallySortedActions[i];
        references = thisAction.expression.getReferences();

        if ((thisAction instanceof DefAction) || (thisAction instanceof ApplyAction)) {
          seen["$" + thisAction.name] = true;
        }
        for (var j = 0; j < references.length; j++) {
          if (!referenceMap[references[j]]) {
            referenceMap[references[j]] = 1;
          } else {
            referenceMap[references[j]]++;
          }
        }
      }

      for (var k in referenceMap) {
        if (!seen[k]) {
          referenceMap[k] = 0;
        }
      }

      // initial steps
      rootNodes = alphabeticallySortedActions.filter(function (thisAction) {
        return (thisAction.expression.getReferences().every((ref) => !referenceMap[ref]));
      });
      alphabeticallySortedActions = alphabeticallySortedActions.filter(function (thisAction) {
        return !(thisAction.expression.getReferences().every((ref) => !referenceMap[ref]));
      });

      // Start sorting
      var checkPrecedence = function (a: Action, b: Action) {
        if (Action.getPrecedenceOrder(a) > Action.getPrecedenceOrder(b)) {
          return 1;
        } else if (Action.getPrecedenceOrder(a) < Action.getPrecedenceOrder(b)) {
          return -1;
        }

        aReferences = a.expression.getReferences();
        bReferences = b.expression.getReferences();

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
      };

      topologicallySortedActions = [];
      while (rootNodes.length > 0) {
        rootNodes.sort(checkPrecedence);
        topologicallySortedActions.push(rootNode = rootNodes.shift())
        if ((rootNode instanceof DefAction) || (rootNode instanceof ApplyAction)) {
          referenceMap["$" + rootNode.name]--;
        }
        for (var i = 0; i < alphabeticallySortedActions.length; i++) {
          var thisAction = alphabeticallySortedActions[i];
          references = thisAction.expression.getReferences();
          if (references.every((ref) => !referenceMap[ref])) {
            rootNodes.push(alphabeticallySortedActions.splice(i, 1)[0]);
          }
        }
      }

      if (alphabeticallySortedActions.length) throw new Error('topological sort error');

      for (var i = 0; i < topologicallySortedActions.length; i++) { //Add limits
        thisAction = topologicallySortedActions[i];
        if (thisAction instanceof SortAction && sortLimitMap[thisAction.toString()]) {
          topologicallySortedActions.splice(i + 1, 0, sortLimitMap[thisAction.toString()])
        }
      }

      value.actions = topologicallySortedActions;

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
        actions = actions.map((action) => {
          return action.substitute((ex: Expression, genDiff: number) => {
            if (genDiff === 0 && ex.isOp('ref') && (<RefExpression>ex).generations === '^') {
              //console.log("replace", ex.toJS());
              //console.log("with", context[(<RefExpression>ex).name]);
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
      var operand = this.operand;

      if (operand.isOp('label')) {
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
