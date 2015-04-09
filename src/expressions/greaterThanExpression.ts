module Facet {
  export class GreaterThanExpression extends BinaryExpression {
    static fromJS(parameters: ExpressionJS): GreaterThanExpression {
      return new GreaterThanExpression(BinaryExpression.jsToValue(parameters));
    }

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this._ensureOp("greaterThan");
      this._checkTypeOf('lhs', 'NUMBER');
      this._checkTypeOf('rhs', 'NUMBER');
      this.type = 'BOOLEAN';
    }

    public toString(): string {
      return `${this.lhs.toString()} > ${this.rhs.toString()}`;
    }

    public simplify(): Expression {
      return (new LessThanExpression({
        op: 'lessThan',
        lhs: this.rhs,
        rhs: this.lhs
      })).simplify()
    }

    protected _getFnHelper(lhsFn: ComputeFn, rhsFn: ComputeFn): ComputeFn {
      return (d: Datum) => lhsFn(d) > rhsFn(d);
    }

    protected _getJSExpressionHelper(lhsFnJS: string, rhsFnJS: string): string {
      return `(${lhsFnJS}>${rhsFnJS})`;
    }

    protected _getSQLHelper(lhsSQL: string, rhsSQL: string, dialect: SQLDialect, minimal: boolean): string {
      return `(${lhsSQL}>${rhsSQL})`;
    }
  }

  Expression.register(GreaterThanExpression);
}
