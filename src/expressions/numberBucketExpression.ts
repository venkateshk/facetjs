module Facet {
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

    public toString(): string {
      return this.operand.toString() + '.numberBucket(' + this.size + (this.offset ? (', ' + this.offset) : '') + ')';
    }

    public equals(other: NumberBucketExpression): boolean {
      return super.equals(other) &&
        this.size === other.size &&
        this.offset === other.offset;
    }

    protected _getFnHelper(operandFn: ComputeFn): ComputeFn {
      var size = this.size;
      var offset = this.offset;
      return (d: Datum) => {
        var num = operandFn(d);
        if (num === null) return null;
        return NumberRange.numberBucket(num, size, offset);
      }
    }

    protected _getJSExpressionHelper(operandFnJS: string): string {
      throw new Error("implement me");
    }

    protected _getSQLHelper(operandSQL: string, dialect: SQLDialect, minimal: boolean): string {
      return continuousFloorExpression(operandSQL, "FLOOR", this.size, this.offset);
    }
  }

  Expression.register(NumberBucketExpression);
}
