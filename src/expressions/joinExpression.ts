module Facet {
  export class JoinExpression extends BinaryExpression {
    static fromJS(parameters: ExpressionJS): JoinExpression {
      return new JoinExpression(BinaryExpression.jsToValue(parameters));
    }

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this._ensureOp("join");

      var rhs = this.rhs;
      var lhs = this.lhs;
      if(!rhs.canHaveType('DATASET')) throw new TypeError('rhs must be a DATASET');
      if(!lhs.canHaveType('DATASET')) throw new TypeError('lhs must be a DATASET');

      this.type = 'DATASET';
    }

    public toString(): string {
      return `${this.lhs.toString()}.join(${this.rhs.toString()})`;
    }

    protected _getFnHelper(lhsFn: ComputeFn, rhsFn: ComputeFn): ComputeFn {
      return (d: Datum) => lhsFn(d).join(rhsFn(d));
    }

    protected _getJSExpressionHelper(lhsFnJS: string, rhsFnJS: string): string {
      return `${lhsFnJS}.join(${rhsFnJS})`;
    }

    protected _getSQLHelper(lhsSQL: string, rhsSQL: string, dialect: SQLDialect, minimal: boolean): string {
      throw new Error('not possible');
    }

    protected _specialSimplify(simpleLhs: Expression, simpleRhs: Expression): Expression {
      if (simpleLhs.equals(simpleRhs)) return simpleLhs;
      return null;
    }

    public _fillRefSubstitutions(typeContext: FullType, indexer: Indexer, alterations: Alterations): FullType {
      indexer.index++;
      var lhsFullType = this.lhs._fillRefSubstitutions(typeContext, indexer, alterations);
      var rhsFullType = this.rhs._fillRefSubstitutions(typeContext, indexer, alterations);

      var lhsDatasetType = lhsFullType.datasetType;
      var rhsDatasetType = rhsFullType.datasetType;
      var myDatasetType: Lookup<FullType> = Object.create(null);

      for (var k in lhsDatasetType) {
        myDatasetType[k] = lhsDatasetType[k];
      }
      for (var k in rhsDatasetType) {
        var ft = rhsDatasetType[k];
        if (hasOwnProperty(myDatasetType, k)) {
          if (myDatasetType[k].type !== ft.type) {
            throw new Error(`incompatible types of joins on ${k} between ${myDatasetType[k].type} and ${ft.type}`);
          }
        } else {
          myDatasetType[k] = ft;
        }
      }

      return {
        parent: lhsFullType.parent,
        type: 'DATASET',
        datasetType: myDatasetType,
        remote: mergeRemotes([lhsFullType.remote, rhsFullType.remote])
      };
    }

  }

  Expression.register(JoinExpression);
}
