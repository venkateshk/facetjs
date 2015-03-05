module Core {
  // [{ applyName: 'Cuts', label: 'Cut', value: 'good-cut' }], name: 'Carats'
  export interface PathPart {
    applyName: string;
    label: string;
    value: any;
  }

  export interface AttachPoint {
    path: PathPart[];
    name: string;
    actions: ActionsExpression;
  }

  export function getAttachPoints(ex: ActionsExpression): AttachPoint[] {
    var operand = ex.operand;
    var actions = ex.actions;

    var action = actions[0];
    if (actions.length === 1 && action instanceof ApplyAction && operand instanceof LiteralExpression) {
      var contexts = (<NativeDataset>operand.value).data;
      var applyName = action.name;
      var applyExpression = action.expression;

      return concatMap(contexts, (datum): AttachPoint[] => {
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

    public filter: Expression;

    constructor(parameters: DatasetValue, dummy: Dummy = null) {
      super(parameters, dummyObject);
      this.filter = parameters.filter;
    }

    public valueOf(): DatasetValue {
      var value = super.valueOf();
      value.filter = this.filter;
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
      return "RemoteDataset(" + this.source + ")";
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

    public addFilter(anotherFilter: Expression): RemoteDataset {
      if (anotherFilter.type !== 'BOOLEAN') throw new Error('must be a boolean');
      var value = this.valueOf();
      value.filter = value.filter.and(anotherFilter).simplify();
      return <RemoteDataset>(new (Dataset.classMap[this.source])(value));
    }

    public generateQueries(ex: Expression): DatastoreQuery[] {
      throw new Error("can not call this directly");
    }
  }
}
