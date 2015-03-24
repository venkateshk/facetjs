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

    public toString(): string {
      return this.operand.toString() + '.timeOffset(' + this.duration.toString() + ')';
    }

    public equals(other: TimeOffsetExpression): boolean {
      return super.equals(other) &&
        this.duration.equals(other.duration);
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

    protected _getSQLHelper(operandSQL: string, dialect: SQLDialect, minimal: boolean): string {
      return dialect.offsetTimeExpression(operandSQL, this.duration);
    }
  }

  Expression.register(TimeOffsetExpression);
}
