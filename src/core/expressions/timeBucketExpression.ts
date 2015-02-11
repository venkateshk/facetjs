module Core {
  export class TimeBucketExpression extends UnaryExpression {
    static fromJS(parameters: ExpressionJS): TimeBucketExpression {
      var value = UnaryExpression.jsToValue(parameters);
      value.duration = parameters.duration;
      return new TimeBucketExpression(value);
    }

    public duration: string;

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this.duration = parameters.duration;
      this._ensureOp("timeBucket");
      this.type = 'TIME_RANGE';
    }

    public toString(): string {
      return 'timeBucket(' + this.operand.toString() + ')';
    }

    public valueOf(): ExpressionValue {
      var value = super.valueOf();
      value.duration = this.duration;
      return value;
    }

    public toJS(): ExpressionJS {
      var js = super.toJS();
      js.duration = this.duration;
      return js;
    }

    public simplify(): Expression {
      return this //TODO
    }

    protected _makeFn(operandFn: Function): Function {
      throw new Error("implement me");
    }

    protected _makeFnJS(operandFnJS: string): string {
      throw new Error("implement me");
    }

    // UNARY
  }

  Expression.register(TimeBucketExpression);

}
