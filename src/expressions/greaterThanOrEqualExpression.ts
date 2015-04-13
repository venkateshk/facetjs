module Facet {
  export class GreaterThanOrEqualExpression extends BinaryExpression {
    static fromJS(parameters: ExpressionJS): GreaterThanOrEqualExpression {
      return new GreaterThanOrEqualExpression(BinaryExpression.jsToValue(parameters));
    }

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this._ensureOp("greaterThanOrEqual");
      this._checkTypeOf('lhs', 'NUMBER');
      this._checkTypeOf('rhs', 'NUMBER');
      this.type = 'BOOLEAN';
    }

    public toString(): string {
      return `${this.lhs.toString()} = ${this.rhs.toString()}`;
    }

    protected _specialSimplify(simpleLhs: Expression, simpleRhs: Expression): Expression {
      return (new LessThanExpression({
        op: 'lessThanOrEqual',
        lhs: simpleLhs,
        rhs: simpleRhs
      })).simplify()
    }

    protected _getFnHelper(lhsFn: ComputeFn, rhsFn: ComputeFn): ComputeFn {
      return (d: Datum) => lhsFn(d) >= rhsFn(d);
    }

    protected _getJSExpressionHelper(lhsFnJS: string, rhsFnJS: string): string {
      return `(${lhsFnJS}>=${rhsFnJS})`;
    }

    protected _getSQLHelper(lhsSQL: string, rhsSQL: string, dialect: SQLDialect, minimal: boolean): string {
      return `(${lhsSQL}>=${rhsSQL})`;
    }
  }

  Expression.register(GreaterThanOrEqualExpression);

}
