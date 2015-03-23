module Core {
  export class LessThanOrEqualExpression extends BinaryExpression {
    static fromJS(parameters: ExpressionJS): LessThanOrEqualExpression {
      return new LessThanOrEqualExpression(BinaryExpression.jsToValue(parameters));
    }

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this._ensureOp("lessThanOrEqual");
      this._checkTypeOf('lhs', 'NUMBER');
      this._checkTypeOf('rhs', 'NUMBER');
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

    protected _getSQLHelper(lhsSQL: string, rhsSQL: string): string {
      return `(${lhsSQL}<=${rhsSQL})`;
    }

    public mergeAnd(exp: Expression): Expression {
      var expLeftHanded: boolean;
      var expVal: any;
      var thisLeftHanded: boolean;
      var thisVal: any;

      thisLeftHanded = this.checkLefthandedness();
      if (thisLeftHanded === null) return null; // if both hands are references. stop trying to merge

      if (exp instanceof BinaryExpression) {
        expLeftHanded = exp.checkLefthandedness();

        expVal = (<LiteralExpression>exp.getOperandOfType('literal')[0]).value;
        thisVal = (<LiteralExpression>this.getOperandOfType('literal')[0]).value;

        if (exp instanceof IsExpression) {
          if (thisLeftHanded) {
            if (expVal < thisVal) {
              return exp;
            } else {
              return Expression.FALSE;
            }
          } else {
            if (expVal > thisVal) {
              return exp;
            } else {
              return Expression.FALSE;
            }
          }
        } else if (exp instanceof LessThanExpression) {
          return exp.mergeAnd(this);
        } else if (exp instanceof LessThanOrEqualExpression) {
          if (thisLeftHanded) {
            if (expLeftHanded) {
              return new LessThanOrEqualExpression({
                op: 'lessThanOrEqual',
                lhs: this.lhs,
                rhs: new LiteralExpression({
                  op: 'literal',
                  value: Math.min(thisVal, expVal)
                })
              });
            } else {
              if (thisVal < expVal) {
                return Expression.FALSE;
              } else {
                return null;
              }
            }
          } else {
            if (expLeftHanded) {
              if (thisVal > expVal) {
                return null; // cannot handle both exclusive/inclusive range
              } else {
                return Expression.FALSE;
              }
            } else {
              return new LessThanOrEqualExpression({
                op: 'lessThanOrEqual',
                lhs: new LiteralExpression({
                  op: 'literal',
                  value: Math.max(thisVal, expVal)
                }),
                rhs: this.rhs
              });
            }
          }
        }
      }
      return null;
    }

    public mergeOr(exp: Expression): Expression {
      var expLeftHanded: boolean;
      var expVal: any;
      var thisLeftHanded: boolean;
      var thisVal: any;

      thisLeftHanded = this.checkLefthandedness();
      if (thisLeftHanded === null) return null; // if both hands are references. stop trying to merge

      if (exp instanceof BinaryExpression) {
        expLeftHanded = exp.checkLefthandedness();

        expVal = (<LiteralExpression>exp.getOperandOfType('literal')[0]).value;
        thisVal = (<LiteralExpression>this.getOperandOfType('literal')[0]).value;

        if (exp instanceof IsExpression) {
          if (thisLeftHanded) {
            if (expVal <= thisVal) {
              return this;
            } else {
              return null;
            }
          } else {
            if (expVal >= thisVal) {
              return this;
            } else {
              return null;
            }
          }
        } else if (exp instanceof LessThanExpression) {
          return exp.mergeOr(this);
        } else if (exp instanceof LessThanOrEqualExpression) {
          if (thisLeftHanded) {
            if (expLeftHanded) {
              return new LessThanOrEqualExpression({
                op: 'lessThanOrEqual',
                lhs: this.lhs,
                rhs: new LiteralExpression({
                  op: 'literal',
                  value: Math.max(thisVal, expVal)
                })
              });
            } else {
              if (thisVal < expVal) {
                return null;
              } else {
                return Expression.TRUE;
              }
            }
          } else {
            if (expLeftHanded) {
              if (thisVal > expVal) {
                return null; // cannot handle both exclusive/inclusive range
              } else {
                return Expression.TRUE;
              }
            } else {
              return new LessThanOrEqualExpression({
                op: 'lessThanOrEqual',
                lhs: new LiteralExpression({
                  op: 'literal',
                  value: Math.min(thisVal, expVal)
                }),
                rhs: this.rhs
              });
            }
          }
        }
      }
      return null;
    }
  }

  Expression.register(LessThanOrEqualExpression);

}
