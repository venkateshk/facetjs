module Core {

  export class NumberBucketExpression extends UnaryExpression {
    static fromJS(parameters: ExpressionJS): NumberBucketExpression {
      var value = UnaryExpression.jsToValue(parameters);
      value.size = parameters.size;
      value.offset = parameters.offset;
      return new NumberBucketExpression(value);
    }

    public offset: number;
    public size: number;

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this.size = parameters.size;
      this.offset = parameters.offset || 0;
      this._ensureOp("numberBucket");
      this.type = "NUMBER_RANGE";
    }

    public toString(): string {
      return 'numberBucket(' + this.operand.toString() + ')';
    }

    public valueOf(): ExpressionValue {
      var value = super.valueOf();
      value.size = this.size;
      value.offset = this.offset;
      return value;
    }

    public toJS(): ExpressionJS {
      var js = super.toJS();
      js.size = this.size;
      if (this.offset) js.offset = this.offset;
      return js;
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
