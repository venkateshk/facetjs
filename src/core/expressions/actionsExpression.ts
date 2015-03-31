module Core {
  export interface QueryPattern {
    pattern: string;
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

    public getFn(): ComputeFn {
      var ex = this;
      var operand = this.operand;
      var actions = this.actions;
      return (d: Datum, def: boolean) => {
        if (d) {
          return ex.resolve(d).simplify().getFn()(null, def);
        }

        var dataset = operand.getFn()(null, def);

        for (var i = 0; i < actions.length; i++) {
          var action = actions[i];
          var actionExpression = action.expression;

          if (action instanceof FilterAction) {
            dataset = dataset.filter(action.expression.getFn());

          } else if (action instanceof ApplyAction) {
            dataset = dataset.apply(action.name, actionExpression.getFn());

          } else if (action instanceof DefAction) {
            dataset = dataset.def(action.name, actionExpression.getFn());

          } else if (action instanceof SortAction) {
            dataset = dataset.sort(actionExpression.getFn(), action.direction);

          } else if (action instanceof LimitAction) {
            dataset = dataset.limit(action.limit);

          }
        }

        return dataset;
      };
    }

    public getJSExpression(): string {
      throw new Error("can not call getJSExpression on actions");
    }

    public getSQL(dialect: SQLDialect, minimal: boolean = false): string {
      throw new Error("can not call getSQL on actions");
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
        references = thisAction.expression.getFreeReferences();

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
        return (thisAction.expression.getFreeReferences().every((ref) => referenceMap[ref] === 0));
      });
      alphabeticallySortedActions = alphabeticallySortedActions.filter(function (thisAction) {
        return !(thisAction.expression.getFreeReferences().every((ref) => !referenceMap[ref]));
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
          references = thisAction.expression.getFreeReferences();
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
      var simpleActions = this.actions.map((action) => action.simplify()); //this._getSimpleActions();

      function isRemoteSimpleApply(action: Action): boolean {
        return action instanceof ApplyAction && action.expression.hasRemote() && action.expression.type !== 'DATASET';
      }

      // These are actions on a remote dataset
      var remoteDatasets = this.getRemoteDatasets();
      var digestedOperand = simpleOperand;
      if (digestedOperand instanceof LiteralExpression && remoteDatasets.length) {
        if (!(<LiteralExpression>simpleOperand).isRemote() && simpleActions.some(isRemoteSimpleApply)) {
          if (remoteDatasets.length === 1) {
            digestedOperand = new LiteralExpression({
              op: 'literal',
              value: remoteDatasets[0].makeTotal()
            });
          } else {
            throw new Error('not done yet')
          }
        }

        var absorbedDefs: DefAction[] = [];
        var undigestedActions: ApplyAction[] = [];
        while (simpleActions.length) {
          var action: Action = simpleActions[0];
          var digest = digestedOperand.digest(action);
          if (!digest) break;
          simpleActions.shift();
          digestedOperand = digest.expression;
          if (digest.undigested) undigestedActions.push(digest.undigested);
          if (action instanceof DefAction) absorbedDefs.push(action);
        }
        if (simpleOperand !== digestedOperand) {
          simpleOperand = digestedOperand;
          var defsToAddBack: Action[] = absorbedDefs.filter((def) => {
            return Action.actionsDependOn(simpleActions, def.name);
          });
          simpleActions = defsToAddBack.concat(undigestedActions, simpleActions);
        }
      }

      if (simpleActions.length === 0) return simpleOperand;
      var simpleValue = this.valueOf();
      simpleValue.operand = simpleOperand;
      simpleValue.actions = simpleActions;
      simpleValue.simple = true;
      return new ActionsExpression(simpleValue);
    }

    protected _specialEvery(iter: BooleanExpressionIterator, depth: number, genDiff: number): boolean {
      return this.actions.every((action) => action._everyHelper(iter, depth + 1, genDiff + 1));
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

    protected _performAction(action: Action): Expression {
      return new ActionsExpression({
        op: 'actions',
        operand: this.operand,
        actions: this.actions.concat(action)
      });
    }

    public _fillRefSubstitutions(typeContext: FullType, alterations: Alteration[]): FullType {
      typeContext = this.operand._fillRefSubstitutions(typeContext, alterations);

      var actions = this.actions;
      for (var i = 0; i < actions.length; i++) {
        var action = actions[i];
        if (action instanceof DefAction || action instanceof ApplyAction) {
          typeContext.datasetType[action.name] = action.expression._fillRefSubstitutions(typeContext, alterations);
        } else if (action instanceof SortAction || action instanceof FilterAction) {
          action.expression._fillRefSubstitutions(typeContext, alterations);
        }
      }

      return typeContext;
    }

    public _computeResolved(): Q.Promise<NativeDataset> {
      var actions = this.actions;

      function execAction(i: number) {
        return (dataset: NativeDataset): NativeDataset | Q.Promise<NativeDataset> => {
          var action = actions[i];
          var actionExpression = action.expression;

          if (action instanceof FilterAction) {
            return dataset.filter(action.expression.getFn());

          } else if (action instanceof ApplyAction) {
            if (actionExpression instanceof ActionsExpression) {
              return dataset.applyPromise(action.name, (d: Datum) => {
                return actionExpression.resolve(d).simplify()._computeResolved();
              });
            } else {
              return dataset.apply(action.name, actionExpression.getFn());
            }

          } else if (action instanceof DefAction) {
            if (actionExpression instanceof ActionsExpression) {
              return dataset.def(action.name, (d: Datum) => {
                var simple = actionExpression.resolve(d).simplify();
                if (simple instanceof LiteralExpression) {
                  return simple.value;
                } else {
                  return simple._computeResolved();
                }
              });
            } else {
              return dataset.def(action.name, actionExpression.getFn());
            }

          } else if (action instanceof SortAction) {
            return dataset.sort(actionExpression.getFn(), action.direction);

          } else if (action instanceof LimitAction) {
            return dataset.limit(action.limit);

          }
        }
      }

      var promise = this.operand._computeResolved();
      for (var i = 0; i < actions.length; i++) {
        promise = promise.then(execAction(i));
      }
      return promise;
    }
  }

  Expression.register(ActionsExpression);
}
