module Facet {
  export class LessThanOrEqualExpression extends BinaryExpression {
    static fromJS(parameters: ExpressionJS): LessThanOrEqualExpression {
      return new LessThanOrEqualExpression(BinaryExpression.jsToValue(parameters));
    }

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this._ensureOp("lessThanOrEqual");
      this._checkMatchingTypes();
      this._checkNumberOrTime();
      this.type = 'BOOLEAN';
    }

    public toString(): string {
      return `${this.lhs.toString()} <= ${this.rhs.toString()}`;
    }

    protected _getFnHelper(lhsFn: ComputeFn, rhsFn: ComputeFn): ComputeFn {
      return (d: Datum) => lhsFn(d) <= rhsFn(d);
    }

    protected _getJSExpressionHelper(lhsFnJS: string, rhsFnJS: string): string {
      return `(${lhsFnJS}<=${rhsFnJS})`;
    }

    protected _getSQLHelper(lhsSQL: string, rhsSQL: string, dialect: SQLDialect, minimal: boolean): string {
      return `(${lhsSQL}<=${rhsSQL})`;
    }

    protected _specialSimplify(simpleLhs: Expression, simpleRhs: Expression): Expression {
      if (simpleLhs instanceof LiteralExpression) { // 5 <= x
        return (new InExpression({
          op: 'in',
          lhs: simpleRhs,
          rhs: $(Range.fromJS({ start: simpleLhs.value, end: null, bounds: '[)' }))
        })).simplify();
      }
      if (simpleRhs instanceof LiteralExpression) { // x <= 5
        return (new InExpression({
          op: 'in',
          lhs: simpleLhs,
          rhs: $(Range.fromJS({ start: null, end: simpleRhs.value, bounds: '(]' }))
        })).simplify();
      }
      return null;
    }
  }

  Expression.register(LessThanOrEqualExpression);

}
