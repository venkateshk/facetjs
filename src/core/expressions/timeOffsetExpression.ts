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
      return this.operand.toString() + '.timeOffset(' + this.duration.toString() + ')';
    }

    protected _getFnHelper(operandFn: ComputeFn): ComputeFn {
      var duration = this.duration;
      return (d: Datum) => {
        var date = operandFn(d);
        if (date === null) return null;
        return duration.move(date, Timezone.UTC(), 1); // ToDo: generalize this
      }
    }

    protected _getJSExpressionHelper(operandFnJS: string): string {
      throw new Error("implement me");
    }

    protected _getSQLHelper(operandSQL: string): string {
      // https://dev.mysql.com/doc/refman/5.5/en/date-and-time-functions.html#function_date-add
      var sqlFn = "DATE_ADD("; //warpDirection > 0 ? "DATE_ADD(" : "DATE_SUB(";
      var spans = this.duration.valueOf();
      var expression = operandSQL;
      if (spans.week) {
        return sqlFn + expression + ", INTERVAL " + String(spans.week) + ' WEEK)';
      }
      if (spans.year || spans.month) {
        var expr = String(spans.year || 0) + "-" + String(spans.month || 0);
        expression = sqlFn + expression + ", INTERVAL '" + expr + "' YEAR_MONTH)";
      }
      if (spans.day || spans.hour || spans.minute || spans.second) {
        var expr = String(spans.day || 0) + " " + [spans.hour || 0, spans.minute || 0, spans.second || 0].join(':');
        expression = sqlFn + expression + ", INTERVAL '" + expr + "' DAY_SECOND)";
      }
      return expression
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

    public equals(other: TimeOffsetExpression): boolean {
      return super.equals(other) &&
        this.duration.equals(other.duration);
    }
  }

  Expression.register(TimeOffsetExpression);
}
