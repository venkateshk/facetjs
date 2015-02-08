module Core {

  export class ReciprocateExpression extends UnaryExpression {
    static fromJS(parameters: ExpressionJS): ReciprocateExpression {
      return new ReciprocateExpression(UnaryExpression.jsToValue(parameters));
    }

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this._ensureOp("reciprocate");
      this.type = 'NUMBER';
    }

    public toString(): string {
      return '1/(' + this.operand.toString() + ')';
    }

    protected _makeFn(operandFn: Function): Function {
      return (d: Datum) => 1 / operandFn(d);
    }

    protected _makeFnJS(operandFnJS: string): string {
      return "1/(" + operandFnJS + ")"
    }

    // UNARY
  }

  Expression.register(ReciprocateExpression);
}
