module Core {

  export class NumberBucketExpression extends UnaryExpression {
    static fromJS(parameters: ExpressionJS): NumberBucketExpression {
      return new NumberBucketExpression(UnaryExpression.jsToValue(parameters));
    }

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this._ensureOp("numberBucket");
      // ToDo: fill with type info?
    }

    public toString(): string {
      return 'numberBucket(' + this.operand.toString() + ')';
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

  Expression.register(NumberBucketExpression);
}
