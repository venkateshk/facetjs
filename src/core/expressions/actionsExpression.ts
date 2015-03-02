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
      return this.operand.toString() + this.actions.map((action) => action.toString()).join('\n  ');
    }

    private _getSimpleActions(): Action[] {
      var filters: FilterAction[];
      var previousSortAction: SortAction;
      var references: string[];
      var rootNode: Action;
      var rootNodes: Action[];
      var simplifiedActions: Action[];
      var sortLimitMap: Lookup<LimitAction>;
      var thisAction: Action;
      var topologicallySortedActions: Action[];

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

      sortLimitMap = {};
      for (var i = 0; i < simplifiedActions.length; i++) {
        var simplifiedAction = simplifiedActions[i];
        if (simplifiedAction instanceof SortAction) previousSortAction = simplifiedAction;

        if ((simplifiedAction instanceof LimitAction) && previousSortAction) {
          sortLimitMap[previousSortAction.toString()] = simplifiedAction;
          previousSortAction = null;
        }
      }

      // Sort topologically
      var seen: Lookup<boolean> = {};
      var referenceMap: Lookup<number> = {};
      var alphabeticallySortedActions = simplifiedActions.filter((action) => !(action instanceof LimitAction))
      for (var i = 0; i < alphabeticallySortedActions.length; i++) {
        thisAction = alphabeticallySortedActions[i];
        references = thisAction.expression.getReferences();

        if (thisAction instanceof DefAction || thisAction instanceof ApplyAction) {
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
        return (thisAction.expression.getReferences().every((ref) => referenceMap[ref] === 0));
      });
      alphabeticallySortedActions = alphabeticallySortedActions.filter(function (thisAction) {
        return !(thisAction.expression.getReferences().every((ref) => !referenceMap[ref]));
      });

      // Start sorting
      topologicallySortedActions = [];
      while (rootNodes.length > 0) {
        rootNodes.sort(Action.compare);
        topologicallySortedActions.push(rootNode = rootNodes.shift());
        if ((rootNode instanceof DefAction) || (rootNode instanceof ApplyAction)) {
          referenceMap["$" + rootNode.name]--;
        }
        var i = 0;
        while (i < alphabeticallySortedActions.length) {
          var thisAction = alphabeticallySortedActions[i];
          references = thisAction.expression.getReferences();
          if (references.every((ref) => referenceMap[ref] === 0)) {
            rootNodes.push(alphabeticallySortedActions.splice(i, 1)[0]);
          } else {
            i++;
          }
        }
      }

      if (alphabeticallySortedActions.length) throw new Error('topological sort error, circular dependency detected');

      // Add limits
      var actionsWithLimits: Action[] = [];
      for (var i = 0; i < topologicallySortedActions.length; i++) {
        thisAction = topologicallySortedActions[i];
        actionsWithLimits.push(thisAction);
        if (thisAction instanceof SortAction && sortLimitMap[thisAction.toString()]) {
          actionsWithLimits.push(sortLimitMap[thisAction.toString()])
        }
      }

      return actionsWithLimits;
    }

    public simplify(): Expression {
      if (this.simple) return this;
      var simpleValue = this.valueOf();
      simpleValue.operand = this.operand.simplify();
      simpleValue.actions = this.actions.map((action) => action.simplify()); //this._getSimpleActions();
      if (simpleValue.actions.length === 0) return simpleValue.operand;
      simpleValue.simple = true;
      return new ActionsExpression(simpleValue);
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

    private _performActionsOnNativeDataset(dataset: NativeDataset, context: Datum): NativeDataset {
      var actions = this.actions;
      if (context) {
        actions = (<ActionsExpression>this.resolve(context)).actions;
      }

      for (var i = 0; i < actions.length; i++) {
        var action = actions[i];
        var actionExpression = action.expression;
        switch (action.action) {
          case 'filter':
            dataset = dataset.filter(action.expression.getFn());
            break;

          case 'apply':
            if (actionExpression instanceof ActionsExpression || actionExpression instanceof LabelExpression) {
              dataset = dataset.apply((<ApplyAction>action).name, (d: Datum) => {
                return actionExpression.evaluate(d)
              });
            } else {
              dataset = dataset.apply((<ApplyAction>action).name, actionExpression.getFn());
            }
            break;

          case 'def':
            if (actionExpression instanceof ActionsExpression || actionExpression instanceof LabelExpression) {
              dataset = dataset.def((<ApplyAction>action).name, (d: Datum) => {
                return actionExpression.evaluate(d)
              });
            } else {
              dataset = dataset.def((<ApplyAction>action).name, actionExpression.getFn());
            }
            break;

          case 'sort':
            dataset = dataset.sort(actionExpression.getFn(), (<SortAction>action).direction);
            break;

          case 'limit':
            dataset = dataset.limit((<LimitAction>action).limit);
            break;
        }
      }

      return dataset;
    }

    public _fillRefSubstitutions(typeContext: any, alterations: Alteration[]): any {
      typeContext = this.operand._fillRefSubstitutions(typeContext, alterations);

      var actions = this.actions;
      for (var i = 0; i < actions.length; i++) {
        var action = actions[i];
        if (action instanceof DefAction || action instanceof ApplyAction) {
          typeContext[action.name] = action.expression._fillRefSubstitutions(typeContext, alterations);
        } else if (action instanceof SortAction || action instanceof FilterAction) {
          action.expression._fillRefSubstitutions(typeContext, alterations);
        }
      }

      return typeContext;
    }

    public _genPlan(hook: string): Expression[] {
      function hookToRef(hook: string): RefExpression {
        return new RefExpression({
          op: 'ref',
          name: hook,
          type: 'DATASET'
        })
      }

      var plan: Expression[] = [];
      var operand = this.operand;
      var actions = this.actions;
      if (!actions.length) throw new Error("Can not plan with empty actions");

      if (operand instanceof LiteralExpression && operand.value.basis()) {
        var simpleActions: Action[] = [];
        var complexActions: Action[] = [];
        for (var i = 0; i < actions.length; i++) {
          var action = actions[i];
          var complex = action instanceof ApplyAction && action.expression.type === 'DATASET'; // ToDo: make this better
          if (complex || complexActions.length) {
            complexActions.push(action);
          } else {
            simpleActions.push(action);
          }
        }

        plan.push(new ActionsExpression({
          op: 'actions',
          operand: hookToRef(hook),
          actions: simpleActions
        }));

        for (var i = 0; i < complexActions.length; i++) {
          var complexApply = <ApplyAction>(complexActions[i]);
          var complexApplyName = complexApply.name;
          var subPlan = complexApply.expression._genPlan(complexApplyName);
          for (var j = 0; j < subPlan.length; j++) {
            plan.push(new ActionsExpression({
              op: 'actions',
              operand: hookToRef(hook),
              actions: [new ApplyAction({
                action: 'apply',
                name: complexApplyName,
                expression: subPlan[j]
              })]
            }));
          }
        }
      } else if (operand instanceof LabelExpression) {
        var simpleActions: Action[] = [];
        var complexActions: Action[] = [];
        for (var i = 0; i < actions.length; i++) {
          var action = actions[i];
          var complex = action instanceof ApplyAction && action.expression.type === 'DATASET'; // ToDo: make this better
          if (complex || complexActions.length) {
            complexActions.push(action);
          } else {
            simpleActions.push(action);
          }
        }

        plan.push(new ActionsExpression({
          op: 'actions',
          operand: operand,
          actions: simpleActions
        }));

        for (var i = 0; i < complexActions.length; i++) {
          var complexApply = <ApplyAction>(complexActions[i]);
          var complexApplyName = complexApply.name;
          var subPlan = complexApply.expression._genPlan(complexApplyName);
          for (var j = 0; j < subPlan.length; j++) {
            plan.push(new ActionsExpression({
              op: 'actions',
              operand: hookToRef(hook),
              actions: [new ApplyAction({
                action: 'apply',
                name: complexApplyName,
                expression: subPlan[j]
              })]
            }));
          }
        }
      } else {
        throw new Error("Can not plan")
      }
      return plan;
    }

    public evaluate(context: Datum = {}): Dataset {
      var operand = this.operand;

      if (operand.isOp('label')) {
        return this._performActionsOnNativeDataset(<NativeDataset>((<LabelExpression>operand).evaluate(context)), context);
      }

      if (operand.isOp('literal')) {
        var ds = <Dataset>(<LiteralExpression>operand).value;
        if (ds.source === 'native') {
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
