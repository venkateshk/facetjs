module Expressions {
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
      return this.lhs.toString() + ' = ' + this.rhs.toString();
    }

    public simplify(): Expression {
      return (new LessThanOrEqualExpression({
        op: 'lessThanOrEqual',
        lhs: this.rhs,
        rhs: this.lhs
      })).simplify()
    }

    protected _makeFn(lhsFn: Function, rhsFn: Function): Function {
      return (d: Datum) => lhsFn(d) >= rhsFn(d);
    }

    protected _makeFnJS(lhsFnJS: string, rhsFnJS: string): string {
      throw '(' + lhsFnJS + '>=' + rhsFnJS + ')';
    }

    // BINARY
  }

  Expression.register(GreaterThanOrEqualExpression);

}
