module Facet {
  //var possiblePartings = 'SECOND_OF_DAY';

  export class TimePartExpression extends UnaryExpression {
    static fromJS(parameters: ExpressionJS): TimePartExpression {
      var value = UnaryExpression.jsToValue(parameters);
      value.part = parameters.part;
      value.timezone = Timezone.fromJS(parameters.timezone);
      return new TimePartExpression(value);
    }

    public part: string;
    public timezone: Timezone;

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this.part = parameters.part;
      this.timezone = parameters.timezone;
      this._ensureOp("timePart");
      this._checkTypeOfOperand('TIME');
      if (typeof this.part !== 'string') {
        throw new Error("`part` must be a string");
      }
      this.type = 'NUMBER';
    }

    public valueOf(): ExpressionValue {
      var value = super.valueOf();
      value.part = this.part;
      value.timezone = this.timezone;
      return value;
    }

    public toJS(): ExpressionJS {
      var js = super.toJS();
      js.part = this.part;
      js.timezone = this.timezone.toJS();
      return js;
    }

    public toString(): string {
      return `${this.operand.toString()}.timePart(${this.part.toString()}, ${this.timezone.toString()})`;
    }

    public equals(other: TimePartExpression): boolean {
      return super.equals(other) &&
        this.part === other.part &&
        this.timezone.equals(other.timezone);
    }

    protected _getFnHelper(operandFn: ComputeFn): ComputeFn {
      var part = this.part;
      var timezone = this.timezone;
      return (d: Datum) => {
        // ToDo: make this work
      }
    }

    protected _getJSExpressionHelper(operandFnJS: string): string {
      throw new Error("implement me");
    }

    protected _getSQLHelper(operandSQL: string, dialect: SQLDialect, minimal: boolean): string {
      // ToDo: make this work
      throw new Error("Vad, srsly make this work")
    }
  }

  Expression.register(TimePartExpression);
}
