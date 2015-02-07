module Expressions {
  export class MatchExpression extends UnaryExpression {
    static fromJS(parameters: ExpressionJS): MatchExpression {
      var value = UnaryExpression.jsToValue(parameters);
      value.regexp = parameters.regexp;
      return new MatchExpression(value);
    }

    public regexp: string;

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this.regexp = parameters.regexp;
      this._ensureOp("match");
      this._checkTypeOfOperand('STRING');
      this.type = 'BOOLEAN';
    }

    public valueOf(): ExpressionValue {
      var value = super.valueOf();
      value.regexp = this.regexp;
      return value;
    }

    public toJS(): ExpressionJS {
      var js = super.toJS();
      js.regexp = this.regexp;
      return js;
    }

    public toString(): string {
      return 'match(' + this.operand.toString() + ', /' + this.regexp + '/)';
    }

    public equals(other: MatchExpression): boolean {
      return super.equals(other) &&
        this.regexp === other.regexp;
    }

    protected _makeFn(operandFn: Function): Function {
      var re = new RegExp(this.regexp);
      return (d: Datum) => re.test(operandFn(d));
    }

    protected _makeFnJS(operandFnJS: string): string {
      return "/" + this.regexp + "/.test(" + operandFnJS + ")";
    }

    // UNARY
  }

  Expression.register(MatchExpression);
}
