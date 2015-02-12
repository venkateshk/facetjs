module Core {
  export class TimeBucketExpression extends UnaryExpression {
    static fromJS(parameters: ExpressionJS): TimeBucketExpression {
      var value = UnaryExpression.jsToValue(parameters);
      value.duration = Duration.fromJS(parameters.duration);
      value.timezone = Timezone.fromJS(parameters.timezone);
      return new TimeBucketExpression(value);
    }

    public duration: Duration;
    public timezone: Timezone;

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this.duration = parameters.duration;
      this.timezone = parameters.timezone;
      this._ensureOp("timeBucket");
      if (!Duration.isDuration(this.duration)) {
        throw new Error("`duration` must be a Duration");
      }
      if (!Timezone.isTimezone(this.timezone)) {
        throw new Error("`timezone` must be a Timezone");
      }
      this.type = 'TIME_RANGE';
    }

    public toString(): string {
      return 'timeBucket(' + this.operand.toString() + ')';
    }

    public valueOf(): ExpressionValue {
      var value = super.valueOf();
      value.duration = this.duration;
      value.timezone = this.timezone;
      return value;
    }

    public toJS(): ExpressionJS {
      var js = super.toJS();
      js.duration = this.duration.toJS();
      js.timezone = this.timezone.toJS();
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

  Expression.register(TimeBucketExpression);

}
