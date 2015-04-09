module Facet {
  var timeBucketing: Lookup<string> = {
    "PT1S": "%Y-%m-%dT%H:%i:%SZ",
    "PT1M": "%Y-%m-%dT%H:%i:00Z",
    "PT1H": "%Y-%m-%dT%H:00:00Z",
    "P1D":  "%Y-%m-%dT00:00:00Z",
    "P1W":  "%Y-%m-%dT00:00:00Z",
    "P1M":  "%Y-%m-00T00:00:00Z",
    "P1Y":  "%Y-00-00T00:00:00Z"
  };

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

    public toString(): string {
      return `${this.operand.toString()}.timeBucket(${this.duration.toString()}, ${this.timezone.toString()})`;
    }

    public equals(other: TimeBucketExpression): boolean {
      return super.equals(other) &&
        this.duration.equals(other.duration) &&
        this.timezone.equals(other.timezone);
    }

    protected _getFnHelper(operandFn: ComputeFn): ComputeFn {
      var duration = this.duration;
      var timezone = this.timezone;
      return (d: Datum) => TimeRange.fromDate(operandFn(d), duration, timezone);
    }

    protected _getJSExpressionHelper(operandFnJS: string): string {
      throw new Error("implement me");
    }

    protected _getSQLHelper(operandSQL: string, dialect: SQLDialect, minimal: boolean): string {
      var bucketFormat = timeBucketing[this.duration.toString()];
      if (!bucketFormat) throw new Error("unsupported duration '" + this.duration + "'");

      var bucketTimezone = this.timezone.toString();
      var expression: string = operandSQL;
      if (bucketTimezone !== "Etc/UTC") {
        expression = `CONVERT_TZ(${expression}, '+0:00', '${bucketTimezone}')`;
      }

      return `DATE_FORMAT(${expression}, '${bucketFormat}')`;
    }
  }

  Expression.register(TimeBucketExpression);

}
