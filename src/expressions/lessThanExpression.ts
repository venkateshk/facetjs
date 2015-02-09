module Core {
  export class LessThanExpression extends BinaryExpression {
    static fromJS(parameters: ExpressionJS): LessThanExpression {
      return new LessThanExpression(BinaryExpression.jsToValue(parameters));
    }

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this._ensureOp("lessThan");
      this._checkTypeOf('lhs', 'NUMBER');
      this._checkTypeOf('rhs', 'NUMBER');
      this.type = 'BOOLEAN';
    }

    public toString(): string {
      return this.lhs.toString() + ' < ' + this.rhs.toString();
    }

    protected _makeFn(lhsFn: Function, rhsFn: Function): Function {
      return (d: Datum) => lhsFn(d) < rhsFn(d);
    }

    protected _makeFnJS(lhsFnJS: string, rhsFnJS: string): string {
      return '(' + lhsFnJS + '<' + rhsFnJS + ')';
    }

    public mergeAnd(exp: Expression): Expression {
      var thisLeftHanded: boolean = this.checkLefthandedness();
      if (thisLeftHanded === null) return null; // if both hands are references. stop trying to merge

      if (exp instanceof BinaryExpression) {
        var expLeftHanded: boolean = exp.checkLefthandedness();

        var expVal = (<LiteralExpression>exp.getOperandOfType('literal')[0]).value;
        var thisVal = (<LiteralExpression>this.getOperandOfType('literal')[0]).value;

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
          if (thisLeftHanded) {
            if (expLeftHanded) {
              return new LessThanExpression({
                op: 'lessThan',
                lhs: this.lhs,
                rhs: new LiteralExpression({
                  op: 'literal',
                  value: Math.min(thisVal, expVal)
                })
              });
            } else {
              if (thisVal <= expVal) {
                return Expression.FALSE;
              } else {
                return null; // cannot handle both exclusive range
              }
            }
          } else {
            if (expLeftHanded) {
              if (thisVal <= expVal) {
                return null; // cannot handle both exclusive range
              } else {
                return Expression.FALSE;
              }
            } else {
              return new LessThanExpression({
                op: 'lessThan',
                lhs: new LiteralExpression({
                  op: 'literal',
                  value: Math.max(thisVal, expVal)
                }),
                rhs: this.rhs
              });
            }
          }
        } else if (exp instanceof LessThanOrEqualExpression) {
          if (thisLeftHanded) {
            if (expLeftHanded) {
              if (thisVal <= expVal) {
                return new LessThanExpression({
                  op: 'lessThan',
                  lhs: this.lhs,
                  rhs: new LiteralExpression({
                    op: 'literal',
                    value: thisVal
                  })
                });
              } else {
                return new LessThanOrEqualExpression({
                  op: 'lessThanOrEqual',
                  lhs: this.lhs,
                  rhs: new LiteralExpression({
                    op: 'literal',
                    value: expVal
                  })
                });
              }
            } else {
              if (thisVal <= expVal) {
                return Expression.FALSE;
              } else {
                return new InExpression({
                  op: 'in',
                  lhs: this.lhs,
                  rhs: new NumberRangeExpression({
                    op: 'numberRange',
                    lhs: new LiteralExpression({ op: 'literal', value: expVal }),
                    rhs: new LiteralExpression({ op: 'literal', value: thisVal })
                  })
                })
              }
            }
          } else {
            if (expLeftHanded) {
              if (thisVal <= expVal) {
                return null; // cannot handle both exclusive/inclusive range
              } else {
                return Expression.FALSE;
              }
            } else {
              if (thisVal >= expVal) {
                return new LessThanExpression({
                  op: 'lessThan',
                  lhs: new LiteralExpression({
                    op: 'literal',
                    value: thisVal
                  }),
                  rhs: this.rhs
                });
              } else {
                return new LessThanOrEqualExpression({
                  op: 'lessThanOrEqual',
                  lhs: new LiteralExpression({
                    op: 'literal',
                    value: expVal
                  }),
                  rhs: this.rhs
                });
              }
            }
          }
        }
      }
      return null;
    }
    // BINARY
  }

  Expression.register(LessThanExpression);
}
