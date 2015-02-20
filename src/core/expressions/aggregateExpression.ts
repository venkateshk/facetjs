module Core {
  export class AggregateExpression extends UnaryExpression {
    static fromJS(parameters: ExpressionJS): AggregateExpression {
      var value = UnaryExpression.jsToValue(parameters);
      value.fn = parameters.fn;
      if (parameters.attribute) {
        value.attribute = Expression.fromJSLoose(parameters.attribute);
      }
      return new AggregateExpression(value);
    }

    public fn: string;
    public attribute: Expression;

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this.fn = parameters.fn;
      this.attribute = parameters.attribute;
      this._ensureOp("aggregate");
      this._checkTypeOfOperand('DATASET');
      this.type = this.fn === 'group' ? 'SET' : 'NUMBER';
      if (this.fn !== 'count' && !this.attribute) {
        throw new Error(this.fn + " aggregate must have an 'attribute'");
      }
    }

    public valueOf(): ExpressionValue {
      var value = super.valueOf();
      value.fn = this.fn;
      if (this.attribute) {
        value.attribute = this.attribute;
      }
      return value;
    }

    public toJS(): ExpressionJS {
      var js = super.toJS();
      if (this.fn) {
        js.fn = this.fn;
      }
      if (this.attribute) {
        js.attribute = this.attribute.toJS();
      }
      return js;
    }

    public equals(other: AggregateExpression): boolean {
      return super.equals(other) &&
        this.fn === other.fn &&
        Boolean(this.attribute) === Boolean(other.attribute) &&
        (!this.attribute || this.attribute.equals(other.attribute));
    }

    public toString(): string {
      return 'agg_' + this.fn + '(' + this.operand.toString() + ')';
    }

    public getComplexity(): number {
      return 1 + this.operand.getComplexity() + (this.attribute ? this.attribute.getComplexity() : 0);
    }

    public simplify(): Expression {
      var value = this.valueOf();
      value.operand = this.operand.simplify();
      if (this.attribute) {
        value.attribute = this.attribute.simplify();
      }
      return new AggregateExpression(value)
    }

    protected _makeFn(operandFn: Function): Function {
      var fn = this.fn;
      var attributeFn = this.attribute ? this.attribute.getFn() : null;
      return (d: Datum) => operandFn(d)[fn](attributeFn);
    }

    protected _makeFnJS(operandFnJS: string): string {
      throw new Error("implement me");
    }

    // UNARY
  }

  Expression.register(AggregateExpression);
}
