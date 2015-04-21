module Facet {
  export class IsExpression extends BinaryExpression {
    static fromJS(parameters: ExpressionJS): IsExpression {
      return new IsExpression(BinaryExpression.jsToValue(parameters));
    }

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this._ensureOp("is");
      this._checkMatchingTypes();
      this.type = 'BOOLEAN';
    }

    public toString(): string {
      return `${this.lhs.toString()} = ${this.rhs.toString()}`;
    }

    protected _getFnHelper(lhsFn: ComputeFn, rhsFn: ComputeFn): ComputeFn {
      return (d: Datum) => lhsFn(d) === rhsFn(d);
    }

    protected _getJSExpressionHelper(lhsFnJS: string, rhsFnJS: string): string {
      return `(${lhsFnJS}===${rhsFnJS})`;
    }

    protected _getSQLHelper(lhsSQL: string, rhsSQL: string, dialect: SQLDialect, minimal: boolean): string {
      return `(${lhsSQL}=${rhsSQL})`;
    }

    public mergeAnd(ex: Expression): Expression {
      if (ex.isOp('literal')) return ex.mergeAnd(this);

      var references = this.getFreeReferences();

      if (!arraysEqual(references, ex.getFreeReferences())) return null;
      if (this.type !== ex.type) return null;

      if (ex instanceof IsExpression) {
        if (references.length === 2) return this;
        if (!(this.lhs instanceof RefExpression && ex.lhs instanceof RefExpression)) return null;

        if (
          (<LiteralExpression>this.rhs).value.valueOf &&
          (<LiteralExpression>ex.rhs).value.valueOf &&
          (<LiteralExpression>ex.rhs).value.valueOf() === (<LiteralExpression>this.rhs).value.valueOf()
        ) return this; // for higher objects
        if ((<LiteralExpression>this.rhs).value === (<LiteralExpression>ex.rhs).value) return this; // for simple values;
        return Expression.FALSE;

      } else if (ex instanceof InExpression) {
        return ex.mergeAnd(this);
      } else {
        return null;
      }
    }

    public mergeOr(ex: Expression): Expression {
      if (ex.isOp('literal')) return ex.mergeOr(this);

      var references = this.getFreeReferences();

      if (!arraysEqual(references, ex.getFreeReferences())) return null;
      if (this.type !== ex.type) return null;

      if (ex instanceof IsExpression) {
        if (references.length === 2) return this;
        if (!(this.lhs instanceof RefExpression && ex.lhs instanceof RefExpression)) return null;

        var thisValue = (<LiteralExpression>this.rhs).value;
        var expValue = (<LiteralExpression>(ex.rhs)).value;

        if (
          thisValue.valueOf &&
          expValue.valueOf &&
          expValue.valueOf() === thisValue.valueOf()
        ) return this; // for higher objects
        if (thisValue === expValue) return this; // for simple values;
        return new InExpression({
          op: 'in',
          lhs: this.lhs,
          rhs: new LiteralExpression({
            op: 'literal',
            value: Set.fromJS([thisValue, expValue])
          })
        });

      } else if (ex instanceof InExpression) {
        return ex.mergeOr(this);
      } else {
        return null;
      }
    }

    protected _specialSimplify(simpleLhs: Expression, simpleRhs: Expression): Expression {
      if (simpleLhs.equals(simpleRhs)) return Expression.TRUE;

      if (simpleLhs instanceof TimeBucketExpression && simpleRhs instanceof LiteralExpression) {
        var duration = simpleLhs.duration;
        var value: TimeRange = simpleRhs.value;
        var start = value.start;
        var end = value.end;

        if (duration.isSimple()) {
          if (duration.floor(start, simpleLhs.timezone).valueOf() === start.valueOf() &&
              duration.move(start, simpleLhs.timezone, 1).valueOf() === end.valueOf()) {
            return new InExpression({
              op: 'in',
              lhs: simpleLhs.operand,
              rhs: simpleRhs
            })
          } else {
            return Expression.FALSE;
          }
        }
      }

      return null;
    }
  }

  Expression.register(IsExpression);

}
