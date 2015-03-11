module Core {
  export interface QueryPattern {
    dataSourceName: string;
    filter: Expression;
    split?: Expression;
    label?: string;
    applies: ApplyAction[];
    sortOrigin?: string;
    sort?: SortAction;
    limit?: LimitAction;
  }

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

      var simpleOperand = this.operand.simplify();

      // Fold filters into remote datasets
      function isResolvedFilter(action: Action) {
        return action instanceof FilterAction && action.expression.resolved();
      }
      if (simpleOperand instanceof LiteralExpression && simpleOperand.isRemote() && this.actions.every(isResolvedFilter)) {
        var remoteDataset = <RemoteDataset>(simpleOperand.value);
        this.actions.forEach((action) => remoteDataset = remoteDataset.addFilter(action.expression))
        return new LiteralExpression({
          op: 'literal',
          value: remoteDataset
        })
      }

      var simpleValue = this.valueOf();
      simpleValue.operand = simpleOperand;
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

    protected _specialEvery(iter: BooleanExpressionIterator): boolean {
      return this.actions.every((action) => action.every(iter));
    }

    protected _specialForEach(iter: VoidExpressionIterator): void {
      return this.actions.forEach((action) => action.forEach(iter));
    }

    public _substituteHelper(substitutionFn: SubstitutionFn, depth: number, genDiff: number): Expression {
      var sub = substitutionFn(this, depth, genDiff);
      if (sub) return sub;
      var subOperand = this.operand._substituteHelper(substitutionFn, depth + 1, genDiff);
      var subActions = this.actions.map((action) => action._substituteHelper(substitutionFn, depth + 1, genDiff + 1));
      if (this.operand === subOperand && this.actions.every((action, i) => action === subActions[i])) return this;

      var value = this.valueOf();
      value.operand = subOperand;
      value.actions = subActions;
      delete value.simple;
      return new ActionsExpression(value);
    }

    protected _makeFn(operandFn: Function): Function {
      throw new Error("can not call makeFn on actions");
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

    public _getExpressionBreakdown(hook: string): Expression[] {
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

      var isBasis = operand instanceof LiteralExpression && operand.value.basis();
      var isLabel = operand instanceof LabelExpression;
      if (isBasis || isLabel) {
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
          var subPlan = complexApply.expression._getExpressionBreakdown(complexApplyName);
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

    private _applyActionsToDataset(dataset: NativeDataset): NativeDataset {
      var actions = this.actions;
      for (var i = 0; i < actions.length; i++) {
        var action = actions[i];
        var actionExpression = action.expression;

        if (action instanceof FilterAction) {
          dataset = dataset.filter(action.expression.getFn());

        } else if (action instanceof ApplyAction) {
          if (actionExpression instanceof ActionsExpression) {
            dataset = dataset.apply(action.name, (d: Datum) => {
              return actionExpression.computeNative(d)
            });
          } else {
            dataset = dataset.apply(action.name, actionExpression.getFn());
          }

        } else if (action instanceof DefAction) {
          if (actionExpression instanceof ActionsExpression) {
            dataset = dataset.def(action.name, (d: Datum) => {
              return actionExpression.computeNative(d)
            });
          } else {
            dataset = dataset.def(action.name, actionExpression.getFn());
          }

        } else if (action instanceof SortAction) {
          dataset = dataset.sort(actionExpression.getFn(), action.direction);

        } else if (action instanceof LimitAction) {
          dataset = dataset.limit(action.limit);

        }
      }

      return dataset;
    }

    public computeNativeResolved(): NativeDataset {
      return this._applyActionsToDataset(this.operand.computeNativeResolved());
    }

    public simulateResolved(): Dataset {
      var actions = this.actions;
      var dataset = this.operand.simulateResolved();

      for (var i = 0; i < actions.length; i++) {
        var action = actions[i];
        var actionExpression = action.expression;

        if (action instanceof ApplyAction) {
          if (actionExpression instanceof ActionsExpression) {
            dataset = dataset.apply(action.name, (d: Datum) => {
              return actionExpression.simulate(d)
            });
          } else {
            dataset = dataset.apply(action.name, () => 5);
          }

        } else if (action instanceof DefAction) {
          if (actionExpression instanceof ActionsExpression || action.expression.type === 'DATASET') {
            dataset = dataset.def(action.name, (d: Datum) => {
              return actionExpression.simulate(d)
            });
          } else {
            dataset = dataset.def(action.name, () => 3);
          }

        } else if (action instanceof SortAction) {
          dataset = dataset.sort(actionExpression.getFn(), action.direction);

        } else if (action instanceof LimitAction) {
          dataset = dataset.limit(action.limit);

        }
      }

      return dataset;
    }

    public totalPattern(): QueryPattern {
      var operand = this.operand;
      var actions = this.actions;
      if (operand instanceof LiteralExpression && operand.value.basis() && actions.length > 1) {
        var action: Action = actions[0];
        var queryPattern: QueryPattern = null;
        if (action instanceof DefAction) {
          queryPattern = {
            dataSourceName: action.name,
            filter: (<RemoteDataset>(<LiteralExpression>action.expression).value).filter, // ToDo: make this a function
            applies: []
          }
        } else {
          return null;
        }

        for (var i = 1; i < actions.length; i++) {
          action = actions[i];
          if (action instanceof ApplyAction) {
            queryPattern.applies.push(action);
          } else {
            return null;
          }
        }

        return queryPattern;
      } else {
        return null;
      }
    }

    public splitPattern(): QueryPattern {
      var labelOperand = this.operand;
      var actions = this.actions;
      if (labelOperand instanceof LabelExpression && actions.length > 1) {
        var groupAggregate = labelOperand.operand;
        if (groupAggregate instanceof AggregateExpression) {
          var action: Action = actions[0];
          var queryPattern: QueryPattern = null;
          if (action instanceof DefAction) {
            queryPattern = {
              dataSourceName: action.name,
              filter: (<RemoteDataset>(<LiteralExpression>groupAggregate.operand).value).filter, // ToDo: make this a function
              split: groupAggregate.attribute,
              label: labelOperand.name,
              applies: []
            }
          } else {
            return null;
          }

          for (var i = 1; i < actions.length; i++) {
            action = actions[i];
            if (action instanceof ApplyAction) {
              queryPattern.applies.push(action);
            } else if (action instanceof SortAction) {
              queryPattern.sortOrigin = 'apply'; // ToDo: fix this
              queryPattern.sort = action;
            } else if (action instanceof LimitAction) {
              queryPattern.limit = action;
            } else {
              return null;
            }
          }

          return queryPattern;
        } else {
          return null;
        }
      } else {
        return null;
      }
    }

  }

  Expression.register(ActionsExpression);
}
