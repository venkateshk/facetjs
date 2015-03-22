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
      return this.operand.toString() + '.timeBucket(' + this.duration.toString() + ', ' + this.timezone.toString() + ')';
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

    public equals(other: TimeBucketExpression): boolean {
      return super.equals(other) &&
        this.duration.equals(other.duration) &&
        this.timezone.equals(other.timezone);
    }

    protected _makeFn(operandFn: ComputeFn): ComputeFn {
      var duration = this.duration;
      var timezone = this.timezone;
      return (d: Datum) => {
        var date = operandFn(d);
        if (date === null) return null;
        return TimeRange.fromDate(date, duration, timezone);
      }
    }

    protected _makeFnJS(operandFnJS: string): string {
      throw new Error("implement me");
    }
  }

  Expression.register(TimeBucketExpression);

}
