module Facet {
  export class TimeBucketExpression extends UnaryExpression {
    static fromJS(parameters: ExpressionJS): TimeBucketExpression {
      return new TimeBucketExpression(UnaryExpression.jsToValue(parameters));
    }

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this._ensureOp("timeBucket");
      this.type = 'TIME_RANGE';
    }

    public toString(): string {
      return 'timeBucket(' + this.operand.toString() + ')';
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
