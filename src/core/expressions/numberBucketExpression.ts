module Core {
  export class NumberBucketExpression extends UnaryExpression {
    static fromJS(parameters: ExpressionJS): NumberBucketExpression {
      var value = UnaryExpression.jsToValue(parameters);
      value.size = parameters.size;
      value.offset = parameters.offset;
      return new NumberBucketExpression(value);
    }

    public size: number;
    public offset: number;

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this.size = parameters.size;
      this.offset = parameters.offset || 0;
      this._ensureOp("numberBucket");
      this.type = "NUMBER_RANGE";
    }

    public toString(): string {
      return this.operand.toString() + '.numberBucket(' + this.size + (this.offset ? (', ' + this.offset) : '') + ')';
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

    public equals(other: NumberBucketExpression): boolean {
      return super.equals(other) &&
        this.size === other.size &&
        this.offset === other.offset;
    }

    protected _makeFn(operandFn: Function): Function {
      var size = this.size;
      var offset = this.offset;
      return (d: Datum) => {
        var num = operandFn(d);
        if (num === null) return null;
        return NumberRange.fromNumber(num, size, offset);
      }
    }

    protected _makeFnJS(operandFnJS: string): string {
      throw new Error("implement me");
    }
  }

  Expression.register(NumberBucketExpression);
}
