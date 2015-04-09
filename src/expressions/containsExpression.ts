module Facet {
  export class ContainsExpression extends BinaryExpression {
    static fromJS(parameters: ExpressionJS): ContainsExpression {
      return new ContainsExpression(BinaryExpression.jsToValue(parameters));
    }

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this._ensureOp("contains");
      var lhs = this.lhs;
      var rhs = this.rhs;

      if (!(lhs.canHaveType('STRING') && rhs.canHaveType('STRING')))   {
        throw new TypeError(`contains expression has a bad type combination ${lhs.type || '?'} contains ${rhs.type || '?'}`);
      }

      this.type = 'BOOLEAN';
    }

    public toString(): string {
      return `${this.lhs.toString()} contains ${this.rhs.toString()}`;
    }

    protected _getFnHelper(lhsFn: ComputeFn, rhsFn: ComputeFn): ComputeFn {
      return (d: Datum) => String(lhsFn(d)).indexOf(lhsFn(d)) > -1;
    }

    protected _getJSExpressionHelper(lhsFnJS: string, rhsFnJS: string): string {
      return `String(${lhsFnJS}).indexOf(${rhsFnJS}) > -1`;
    }

    protected _getSQLHelper(lhsSQL: string, rhsSQL: string, dialect: SQLDialect, minimal: boolean): string {
      var rhs = this.rhs;
      if (rhs instanceof LiteralExpression) {
        return `${lhsSQL} LIKE "%${rhs.value}%"`;
      } else {
        throw new Error(`can not express ${rhs.toString()} in SQL`);
      }
    }
  }

  Expression.register(ContainsExpression);
}
