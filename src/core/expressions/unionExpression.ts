module Core {
  function emptyLiteralSet(ex: Expression): boolean {
    if (ex instanceof LiteralExpression) {
      return (<Set>ex.value).empty()
    } else {
      return false;
    }
  }

  export class UnionExpression extends BinaryExpression {
    static fromJS(parameters: ExpressionJS): UnionExpression {
      return new UnionExpression(BinaryExpression.jsToValue(parameters));
    }

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this._ensureOp("union");

      var rhs = this.rhs;
      var lhs = this.lhs;
      if(!rhs.canHaveType('SET')) throw new TypeError('rhs must be a SET');
      if(!lhs.canHaveType('SET')) throw new TypeError('lhs must be a SET');

      var lhsType = lhs.type;
      var rhsType = rhs.type;
      if (String(lhsType).indexOf('/') > 0 && String(rhsType).indexOf('/') > 0 && lhsType !== rhsType) {
        throw new TypeError(`UNION expression must have matching set types, (are: ${lhsType}, ${rhsType})`);
      }
      this.type = String(lhsType).indexOf('/') > 0 ? lhsType : rhsType;
    }

    public toString(): string {
      return `(${this.lhs.toString()} U ${this.rhs.toString()})`;
    }

    protected _getFnHelper(lhsFn: ComputeFn, rhsFn: ComputeFn): ComputeFn {
      return (d: Datum) => lhsFn(d).union(rhsFn(d));
    }

    protected _getJSExpressionHelper(lhsFnJS: string, rhsFnJS: string): string {
      return `${lhsFnJS}.union(${rhsFnJS})`;
    }

    protected _getSQLHelper(lhsSQL: string, rhsSQL: string, dialect: SQLDialect, minimal: boolean): string {
      throw new Error('not possible');
    }

    protected _specialSimplify(simpleLhs: Expression, simpleRhs: Expression): Expression {
      // If sets are the same then there is not need for a union
      if (simpleLhs.equals(simpleRhs)) return simpleLhs;

      // If one of the sets is empty then there is no need for a union
      if (emptyLiteralSet(simpleLhs)) return simpleRhs;
      if (emptyLiteralSet(simpleRhs)) return simpleLhs;

      return null;
    }

    public _fillRefSubstitutions(typeContext: FullType, alterations: Alteration[]): FullType {
      var lhsFullType = this.lhs._fillRefSubstitutions(typeContext, alterations);
      var rhsFullType = this.rhs._fillRefSubstitutions(typeContext, alterations);
      return {
        type: String(lhsFullType.type).indexOf('/') > 0 ? lhsFullType.type : rhsFullType.type,
        remote: mergeRemotes([lhsFullType.remote, rhsFullType.remote])
      };
    }
  }

  Expression.register(UnionExpression);

}
