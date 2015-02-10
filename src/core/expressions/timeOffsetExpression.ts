module Core {
  export class TimeOffsetExpression extends UnaryExpression {
    static fromJS(parameters: ExpressionJS): TimeOffsetExpression {
      return new TimeOffsetExpression(UnaryExpression.jsToValue(parameters));
    }

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this._ensureOp("timeOffset");
      this._checkTypeOfOperand('TYPE');
      this.type = 'TIME';
    }

    public toString(): string {
      return 'timeOffset(' + this.operand.toString() + ')';
    }

    // ToDo: equals

    public simplify(): Expression {
      return this //ToDo
    }

    protected _makeFn(operandFn: Function): Function {
      throw new Error("implement me");
    }

    protected _makeFnJS(operandFnJS: string): string {
      throw new Error("implement me");
    }

    // UNARY
  }

  Expression.register(TimeOffsetExpression);
}
