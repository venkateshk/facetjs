module Core {
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
      return this.lhs.toString() + ' > ' + this.rhs.toString();
    }

    public simplify(): Expression {
      return (new LessThanExpression({
        op: 'lessThan',
        lhs: this.rhs,
        rhs: this.lhs
      })).simplify()
    }

    protected _makeFn(lhsFn: Function, rhsFn: Function): Function {
      return (d: Datum) => lhsFn(d) > rhsFn(d);
    }

    protected _makeFnJS(lhsFnJS: string, rhsFnJS: string): string {
      throw '(' + lhsFnJS + '>' + rhsFnJS + ')';
    }

    // BINARY
  }

  Expression.register(GreaterThanExpression);
}
