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
                  rhs: new LiteralExpression({
                    op: 'literal',
                    value: new NumberRange({ start: expVal, end: thisVal })
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
            if (expVal < thisVal) {
              return this;
            } else {
              return null;
            }
          } else {
            if (expVal > thisVal) {
              return this;
            } else {
              return null;
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
                  value: Math.max(thisVal, expVal)
                })
              });
            } else {
              if (thisVal < expVal) {
                return null;
              } else if (thisVal === expVal) {
                return new NotExpression({
                  op: 'not',
                  operand: new IsExpression({
                    op: 'is',
                    lhs: this.lhs,
                    rhs: new LiteralExpression({
                      op: 'literal',
                      value: thisVal
                    })
                  })
                });
              } else {
                return Expression.TRUE; // cannot handle both exclusive range
              }
            }
          } else {
            if (expLeftHanded) {
              if (thisVal < expVal) {
                return Expression.TRUE;
              } else if (thisVal === expVal) {
                return new NotExpression({
                  op: 'not',
                  operand: new IsExpression({
                    op: 'is',
                    lhs: this.rhs,
                    rhs: new LiteralExpression({
                      op: 'literal',
                      value: thisVal
                    })
                  })
                });
              } else {
                return null;
              }
            } else {
              return new LessThanExpression({
                op: 'lessThan',
                lhs: new LiteralExpression({
                  op: 'literal',
                  value: Math.min(thisVal, expVal)
                }),
                rhs: this.rhs
              });
            }
          }
        } else if (exp instanceof LessThanOrEqualExpression) {
          if (thisLeftHanded) {
            if (expLeftHanded) {
              if (thisVal <= expVal) {
                return new LessThanOrEqualExpression({
                  op: 'lessThanOrEqual',
                  lhs: this.lhs,
                  rhs: new LiteralExpression({
                    op: 'literal',
                    value: expVal
                  })
                });
              } else {
                return new LessThanExpression({
                  op: 'lessThan',
                  lhs: this.lhs,
                  rhs: new LiteralExpression({
                    op: 'literal',
                    value: thisVal
                  })
                });
              }
            } else {
              if (thisVal < expVal) {
                return null;
              } else {
                return Expression.TRUE;
              }
            }
          } else {
            if (expLeftHanded) {
              if (thisVal <= expVal) {
                return Expression.TRUE;
              } else {
                return null;
              }
            } else {
              if (thisVal >= expVal) {
                return new LessThanOrEqualExpression({
                  op: 'lessThanOrEqual',
                  lhs: new LiteralExpression({
                    op: 'literal',
                    value: expVal
                  }),
                  rhs: this.rhs
                });
              } else {
                return new LessThanExpression({
                  op: 'lessThan',
                  lhs: new LiteralExpression({
                    op: 'literal',
                    value: thisVal
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
