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
      var simpleActions = this.actions.map((action) => action.simplify()); //this._getSimpleActions();

      function isRemoteNumericApply(action: Action): boolean {
        return action instanceof ApplyAction && action.expression.hasRemote() && action.expression.type === 'NUMBER';
      }

      // These are actions on a remote dataset
      var remoteDatasets = this.getRemoteDatasets();
      if (simpleOperand instanceof LiteralExpression && remoteDatasets.length) {
        var remoteDataset: RemoteDataset;
        if ((<LiteralExpression>simpleOperand).isRemote()) {
          remoteDataset = (<LiteralExpression>simpleOperand).value;
        } else if (simpleActions.some(isRemoteNumericApply)) {
          if (remoteDatasets.length === 1) {
            remoteDataset = remoteDatasets[0].makeTotal();
          } else {
            throw new Error('not done yet')
          }
        }

        if (remoteDataset) {
          while (simpleActions.length) {
            var action: Action = simpleActions[0];
            var newRemoteDataset = remoteDataset.addAction(action);
            if (!newRemoteDataset) break;
            simpleActions.shift();
            remoteDataset = newRemoteDataset;
          }
          if ((<LiteralExpression>simpleOperand).value !== remoteDataset) {
            simpleOperand = new LiteralExpression({
              op: 'literal',
              value: remoteDataset
            });
            if (simpleActions.length) {
              simpleActions = (<Action[]>remoteDataset.defs).concat(simpleActions);
            }
          }
        }
      }

      if (simpleActions.length === 0) return simpleOperand;
      var simpleValue = this.valueOf();
      simpleValue.operand = simpleOperand;
      simpleValue.actions = simpleActions;
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

    public _computeNativeResolved(queries: any[]): NativeDataset {
      var dataset = this.operand._computeNativeResolved(queries);

      var actions = this.actions;
      for (var i = 0; i < actions.length; i++) {
        var action = actions[i];
        var actionExpression = action.expression;

        if (action instanceof FilterAction) {
          dataset = dataset.filter(action.expression.getFn());

        } else if (action instanceof ApplyAction) {
          if (actionExpression instanceof LiteralExpression) {
            var v = actionExpression._computeNativeResolved(queries);
            dataset = dataset.apply(action.name, () => v);
          } else if (actionExpression instanceof ActionsExpression) {
            dataset = dataset.apply(action.name, (d: Datum) => {
              return actionExpression.resolve(d).simplify()._computeNativeResolved(queries)
            });
          } else {
            dataset = dataset.apply(action.name, actionExpression.getFn());
          }

        } else if (action instanceof DefAction) {
          if (actionExpression instanceof ActionsExpression) {
            dataset = dataset.def(action.name, (d: Datum) => {
              var simple = actionExpression.resolve(d).simplify();
              if (simple instanceof LiteralExpression) {
                return simple.value;
              } else {
                return simple._computeNativeResolved(queries);
              }
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

    public _computeResolved(): Q.Promise<any> {
      var actions = this.actions;
      return this.operand._computeResolved().then((dataset) => {
        for (var i = 0; i < actions.length; i++) {
          var action = actions[i];
          var actionExpression = action.expression;

          if (action instanceof FilterAction) {
            dataset = dataset.filter(action.expression.getFn());

          } else if (action instanceof ApplyAction) {
            if (actionExpression instanceof ActionsExpression) {
              dataset = dataset.applyPromise(action.name, (d: Datum) => {
                return actionExpression.resolve(d).simplify()._computeResolved();
              });
            } else {
              dataset = dataset.apply(action.name, actionExpression.getFn());
            }

          } else if (action instanceof DefAction) {
            if (actionExpression instanceof ActionsExpression) {
              dataset = dataset.def(action.name, (d: Datum) => {
                var simple = actionExpression.resolve(d).simplify();
                if (simple instanceof LiteralExpression) {
                  return simple.value;
                } else {
                  return simple._computeResolved();
                }
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
      })
    }
  }

  Expression.register(ActionsExpression);
}
