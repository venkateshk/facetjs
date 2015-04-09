module Facet {
  export class TimeOffsetExpression extends UnaryExpression {
    static fromJS(parameters: ExpressionJS): TimeOffsetExpression {
      var value = UnaryExpression.jsToValue(parameters);
      value.duration = Duration.fromJS(parameters.duration);
      value.timezone = Timezone.fromJS(parameters.timezone);
      return new TimeOffsetExpression(value);
    }

    public duration: Duration;
    public timezone: Timezone;

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this.duration = parameters.duration;
      this.timezone = parameters.timezone;
      this._ensureOp("timeOffset");
      this._checkTypeOfOperand('TIME');
      if (!Duration.isDuration(this.duration)) {
        throw new Error("`duration` must be a Duration");
      }
      this.type = 'TIME';
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
      return `${this.operand.toString()}.timeOffset(${this.duration.toString()}, ${this.timezone.toString()})`;
    }

    public equals(other: TimeBucketExpression): boolean {
      return super.equals(other) &&
        this.duration.equals(other.duration) &&
        this.timezone.equals(other.timezone);
    }

    protected _getFnHelper(operandFn: ComputeFn): ComputeFn {
      var duration = this.duration;
      var timezone = this.timezone;
      return (d: Datum) => {
        var date = operandFn(d);
        if (date === null) return null;
        return duration.move(date, timezone, 1); // ToDo: generalize direction
      }
    }

    protected _getJSExpressionHelper(operandFnJS: string): string {
      throw new Error("implement me");
    }

    protected _getSQLHelper(operandSQL: string, dialect: SQLDialect, minimal: boolean): string {
      return dialect.offsetTimeExpression(operandSQL, this.duration);
    }
  }

  Expression.register(TimeOffsetExpression);
}
