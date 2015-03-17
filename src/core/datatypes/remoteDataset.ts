module Core {
  export function getAttachPoints(ex: ActionsExpression): ExpressionAttachPoint[] {
    var operand = ex.operand;
    var actions = ex.actions;

    var action = actions[0];
    if (actions.length === 1 && action instanceof ApplyAction && operand instanceof LiteralExpression) {
      var contexts = (<NativeDataset>operand.value).data;
      var applyName = action.name;
      var applyExpression = action.expression;

      return concatMap(contexts, (datum): ExpressionAttachPoint[] => {
        var resolvedExpression = <ActionsExpression>(applyExpression.resolve(datum).simplify());
        if (resolvedExpression.operand instanceof LabelExpression) {
          return [{
            path: [],
            name: applyName,
            actions: resolvedExpression
          }]
        } else {
          var attachPoints = getAttachPoints(resolvedExpression);
          // ToDo: update paths
          return attachPoints;
        }
      })

    } else if (actions.every((action) => action instanceof DefAction || (action instanceof ApplyAction && action.expression.type == 'NUMBER'))) {
      return [{
        path: [],
        name: null,
        actions: ex
      }]

    } else {
      throw new Error("not supported: " + ex.toString());
    }
  }

  export class RemoteDataset extends Dataset {
    static type = 'DATASET';

    static jsToValue(parameters: any): DatasetValue {
      var value = Dataset.jsToValue(parameters);
      value.filter = parameters.filter || Expression.TRUE;
      return value;
    }

    public mode: string; // raw, total, split (potential aggregate mode)
    public derivedAttributes: ApplyAction[];
    public filter: Expression;
    public split: Expression;
    public label: string;
    public applies: ApplyAction[];
    public sort: SortAction;
    public sortOrigin: string;
    public limit: LimitAction;
    public havingFilter: Expression;
    public fullJoin: RemoteDataset; // ToDo: maybe a good idea to have chain joins
    public leftJoin: RemoteDataset;

    // ToDo: notes
    // need .select aggregator == .firstInGroup()
    // Remote dataset to number (maxTime)
    // .apply('maxTime', $data.max($time))
    // => .apply($maxTime, ds.apply($tmp, $max($time)).select($tmp))
    // side q: allow .apply($maxTime, $data.max($time)) ?

    constructor(parameters: DatasetValue, dummy: Dummy = null) {
      super(parameters, dummyObject);
      this.mode = parameters.mode || 'raw';
      this.derivedAttributes = parameters.derivedAttributes || [];
      this.filter = parameters.filter || Expression.TRUE;
      this.split = parameters.split;
      this.label = parameters.label;
      this.applies = parameters.applies;
      this.sort = parameters.sort;
      this.sortOrigin = parameters.sortOrigin;
      this.limit = parameters.limit;
      this.havingFilter = parameters.havingFilter;

      if (this.mode !== 'raw') {
        this.applies = this.applies || [];

        if (this.mode === 'split') {
          if (!this.split) throw new Error('must have split in split mode');
          if (!this.label) throw new Error('must have label in split mode');
        }
      }
    }

    public valueOf(): DatasetValue {
      var value = super.valueOf();
      value.mode = this.mode;
      value.derivedAttributes = this.derivedAttributes;
      value.filter = this.filter;
      value.split = this.split;
      value.label = this.label;
      value.applies = this.applies;
      value.sort = this.sort;
      value.sortOrigin = this.sortOrigin;
      value.limit = this.limit;
      value.havingFilter = this.havingFilter;
      return value;
    }

    public toJS(): DatasetJS {
      var js = super.toJS();
      if (!this.filter.equals(Expression.TRUE)) {
        js.filter = this.filter.toJS();
      }
      return js;
    }

    public toString(): string {
      switch (this.mode) {
        case 'raw':
          return `RemoteRaw(${this.filter.toString()})`;

        case 'total':
          return `RemoteTotal(${this.applies.length})`;

        case 'split':
          return `RemoteSplit(${this.applies.length})`;

        default :
          return 'Remote()';
      }

    }

    public equals(other: RemoteDataset): boolean {
      return super.equals(other) &&
        this.filter.equals(other.filter);
    }

    public hasRemote(): boolean {
      return true;
    }

    public getRemoteDatasets(): RemoteDataset[] {
      return [this];
    }

    // -----------------

    public canHandleFilter(ex: Expression): boolean {
      return true;
    }

    public canHandleTotal(): boolean {
      return true;
    }

    public canHandleSplit(ex: Expression): boolean {
      return true;
    }

    public canHandleSort(sortAction: SortAction): boolean {
      return true;
    }

    public canHandleLimit(limitAction: LimitAction): boolean {
      return true;
    }

    public canHandleHavingFilter(ex: Expression): boolean {
      return true;
    }

    public makeTotal(): RemoteDataset {
      if (this.mode !== 'raw') return null; // Can only split on 'raw' datasets
      if (!this.canHandleTotal()) return null;

      var value = this.valueOf();
      value.mode = 'total';

      return <RemoteDataset>(new (Dataset.classMap[this.source])(value));
    }

    public addSplit(splitExpression: Expression, label: string): RemoteDataset {
      if (this.mode !== 'raw') return null; // Can only split on 'raw' datasets
      if (!this.canHandleSplit(splitExpression)) return null;

      var value = this.valueOf();
      value.mode = 'split';
      value.split = splitExpression;
      value.label = label;

      return <RemoteDataset>(new (Dataset.classMap[this.source])(value));
    }

    public addAction(action: Action): RemoteDataset {
      var value = this.valueOf();
      var expression = action.expression;

      if (action instanceof FilterAction) {
        if (!expression.resolved()) return null;

        switch (this.mode) {
          case 'raw':
            if (!this.canHandleFilter(expression)) return null;
            value.filter = value.filter.and(expression).simplify();
            break;

          case 'split':
            if (!this.canHandleHavingFilter(expression)) return null;
            value.havingFilter = value.havingFilter.and(expression).simplify();
            break;

          default:
            return null; // can not add filter in total mode
        }

      } else if (action instanceof DefAction) {
        if (expression.type !== 'DATASET') return null;

        switch (this.mode) {
          case 'total':
            if (expression instanceof LiteralExpression) {
              var otherDataset: RemoteDataset = expression.value;
              value.derivedAttributes = otherDataset.derivedAttributes;
              value.filter = otherDataset.filter;
            } else {
              return null;
            }
            break;

          case 'split':
            // Expect it to be .def('myData', facet('myData').filter(split = ^label)
            var defExpression = action.expression;
            if (defExpression instanceof ActionsExpression &&
              defExpression.actions.length === 1 &&
              defExpression.actions[0].action === 'filter' &&
              defExpression.actions[0].expression.equals(this.split.is(new RefExpression({ op: 'ref', name: '^' + this.label })))) {
              // segmentDatasetName

            } else {
              return null;
            }
            break;

          default:
            return null; // can not add filter in total mode
        }

      } else if (action instanceof ApplyAction) {
        if (expression.type !== 'NUMBER') return null;

        if (this.mode === 'raw') {
          value.derivedAttributes = value.derivedAttributes.concat(action);
        } else {
          value.applies = value.applies.concat(action)
        }

      } else if (action instanceof SortAction) {
        if (!this.canHandleSort(action)) return null;
        value.sort = action;

      } else if (action instanceof LimitAction) {
        if (!this.canHandleLimit(action)) return null;
        value.limit = action;

      } else {
        return null;
      }

      return <RemoteDataset>(new (Dataset.classMap[this.source])(value));
    }

    // -----------------

    public getQuery(): any {
      throw new Error("can not call getQuery directly");
    }

    public getPostProcess(): PostProcess {
      throw new Error("can not call getPostProcess directly");
    }

    public generateQueries(ex: Expression): QueryAttachPoint[] {
      /*
      var attachPaths = getAttachPoints(<ActionsExpression>ex);
      return attachPaths.map((attachPath) => {
        var datastoreQuery = this.actionsToQuery(attachPath.actions);
        return {
          path: attachPath.path,
          name: attachPath.name,
          query: datastoreQuery.query,
          post: datastoreQuery.post
        }
      }, this);
      */
      return null;
    }
  }
}
