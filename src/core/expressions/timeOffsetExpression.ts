module Core {
  export class TimeOffsetExpression extends UnaryExpression {
    static fromJS(parameters: ExpressionJS): TimeOffsetExpression {
      var value = UnaryExpression.jsToValue(parameters);
      value.duration = Duration.fromJS(parameters.duration);
      return new TimeOffsetExpression(value);
    }

    public duration: Duration;

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this.duration = parameters.duration;
      this._ensureOp("timeOffset");
      this._checkTypeOfOperand('TIME');
      if (!Duration.isDuration(this.duration)) {
        throw new Error("`duration` must be a Duration");
      }
      this.type = 'TIME';
    }

    public toString(): string {
      return 'timeOffset(' + this.operand.toString() + ')';
    }

    public valueOf(): ExpressionValue {
      var value = super.valueOf();
      value.duration = this.duration;
      return value;
    }

    public toJS(): ExpressionJS {
      var js = super.toJS();
      js.duration = this.duration.toJS();
      return js;
    }

    // ToDo: equals

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
