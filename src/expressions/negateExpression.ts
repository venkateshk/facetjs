module Facet {
  export class NegateExpression extends UnaryExpression {
    static fromJS(parameters: ExpressionJS): NegateExpression {
      return new NegateExpression(UnaryExpression.jsToValue(parameters));
    }

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this._ensureOp("negate");
      this.type = 'NUMBER';
    }

    public toString(): string {
      return 'negate(' + this.operand.toString() + ')';
    }

    protected _makeFn(operandFn: Function): Function {
      return (d: Datum) => -operandFn(d);
    }

    protected _makeFnJS(operandFnJS: string): string {
      return "-(" + operandFnJS + ")"
    }

    // UNARY
  }

  Expression.register(NegateExpression);

}
