module Core {

  export class NumberBucketExpression extends UnaryExpression {
    static fromJS(parameters: ExpressionJS): NumberBucketExpression {
      var value = UnaryExpression.jsToValue(parameters);
      value.size= parameters.size;
      if (parameters.offset) value.offset = parameters.offset;
      return new NumberBucketExpression(value);
    }

    public offset: number;
    public size: number;

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this.size= parameters.size;
      if (parameters.offset) this.offset = parameters.offset;
      this._ensureOp("numberBucket");
      // ToDo: fill with type info?
    }

    public toString(): string {
      return 'numberBucket(' + this.operand.toString() + ')';
    }

    public valueOf(): ExpressionValue {
      var value = super.valueOf();
      value.size = this.size;
      if (this.offset) value.offset = this.offset;
      return value;
    }

    public toJS(): ExpressionJS {
      var js = super.toJS();
      js.size = this.size;
      if (this.offset) js.offset = this.offset;
      return js;
    }

    public simplify(): Expression {
      var value = this.valueOf();
      value.operand = value.operand.simplify();
      return new NumberBucketExpression(value); //TODO
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
