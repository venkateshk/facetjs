module Core {

  export class IsExpression extends BinaryExpression {
    static fromJS(parameters: ExpressionJS): IsExpression {
      return new IsExpression(BinaryExpression.jsToValue(parameters));
    }

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this._ensureOp("is");
      var lhsType = this.lhs.type;
      var rhsType = this.rhs.type;
      if (lhsType && rhsType && lhsType !== rhsType) {
        throw new TypeError('is expression must have matching types, (are: ' + lhsType + ', ' + rhsType + ')');
      }
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

    public getComplexity(): number {
      return 1 + this.lhs.getComplexity() + this.rhs.getComplexity();
    }

    public mergeAnd(exp: Expression): Expression {
      var references = this.getReferences();

      if (!checkArrayEquality(references, exp.getReferences())) return null;
      if (this.type !== exp.type) return null;

      if (exp instanceof IsExpression) {
        if (references.length === 2) return this;
        if (!(this.lhs instanceof RefExpression && exp.lhs instanceof RefExpression)) return null;

        if (
          (<LiteralExpression>(this.rhs)).value.valueOf &&
          (<LiteralExpression>(exp).rhs).value.valueOf &&
          (<LiteralExpression>(exp).rhs).value.valueOf() === (<LiteralExpression>(this.rhs)).value.valueOf()
        ) return this; // for higher objects
        if ((<LiteralExpression>(this.rhs)).value === (<LiteralExpression>(exp).rhs).value) return this; // for simple values;
        return Expression.FALSE;

      } else if (exp instanceof InExpression) {
        if (references.length === 2) return null;
        if (!(this.lhs instanceof RefExpression && exp.lhs instanceof RefExpression)) return null;

        var expRhs = exp.rhs;
        var thisValue = (<LiteralExpression>(this.rhs)).value;

        if (expRhs instanceof LiteralExpression) {
          var rValue = expRhs.value;
          if (rValue instanceof Set || rValue instanceof TimeRange || rValue instanceof NumberRange) {
            if (rValue.contains(thisValue)) {
              return this;
            } else {
              return Expression.FALSE;
            }
          }
        }
        return null;
      } else {
        return null;
      }
    }

    public mergeOr(exp: Expression): Expression {
      var references = this.getReferences();

      if (!checkArrayEquality(references, exp.getReferences())) return null;
      if (this.type !== exp.type) return null;

      if (exp instanceof IsExpression) {
        if (references.length === 2) return this;
        if (!(this.lhs instanceof RefExpression && exp.lhs instanceof RefExpression)) return null;

        var thisValue = (<LiteralExpression>(this.rhs)).value;
        var expValue = (<LiteralExpression>(exp.rhs)).value;

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

      } else if (exp instanceof InExpression) {
        if (references.length === 2) return null;
        if (!(this.lhs instanceof RefExpression && exp.lhs instanceof RefExpression)) return null;

        var expRhs = exp.rhs;
        var thisValue = (<LiteralExpression>(this.rhs)).value;

        if (expRhs instanceof LiteralExpression) {
          var rValue = expRhs.value;
          if (rValue instanceof Set) {
            if (rValue.contains(thisValue)) {
              return exp;
            } else {
              return new InExpression({
                op: 'in',
                lhs: this.lhs,
                rhs: new LiteralExpression({
                  op: 'literal',
                  value: rValue.add(thisValue)
                })
              });
            }
          } else if (rValue instanceof TimeRange || rValue instanceof NumberRange) {
            if (rValue.contains(thisValue)) {
              return exp;
            } else {
              return null;
            }
          }
        }
        return null;
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
