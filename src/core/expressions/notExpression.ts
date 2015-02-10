module Core {
  export class NotExpression extends UnaryExpression {
    static fromJS(parameters: ExpressionJS): NotExpression {
      return new NotExpression(UnaryExpression.jsToValue(parameters));
    }

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this._ensureOp("not");
      this._checkTypeOfOperand('BOOLEAN');
      this.type = 'BOOLEAN';
    }

    public toString(): string {
      return 'not(' + this.operand.toString() + ')';
    }

    protected _makeFn(operandFn: Function): Function {
      return (d: Datum) => !operandFn(d);
    }

    protected _makeFnJS(operandFnJS: string): string {
      return "!(" + operandFnJS + ")"
    }

    // UNARY
  }

  Expression.register(NotExpression);
}
