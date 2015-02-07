module Facet {

  export class LabelExpression extends UnaryExpression {
    static fromJS(parameters: ExpressionJS): LabelExpression {
      var value = UnaryExpression.jsToValue(parameters);
      value.name = parameters.name;
      return new LabelExpression(value);
    }

    public name: string;

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this.name = parameters.name;
      this._ensureOp("label");
      this._checkTypeOfOperand('SET');
      if (!this.name) throw new Error('split must have a name');
      this.type = 'DATASET';
    }

    public valueOf(): ExpressionValue {
      var value = super.valueOf();
      value.name = this.name;
      return value;
    }

    public toJS(): ExpressionJS {
      var js = super.toJS();
      js.name = this.name;
      return js;
    }

    public toString(): string {
      return 'label(' + this.operand.toString() + ' as ' + this.name + ')';
    }

    public equals(other: LabelExpression): boolean {
      return super.equals(other) &&
        this.name === other.name;
    }

    protected _makeFn(operandFn: Function): Function {
      throw new Error("can not call on split");
    }

    protected _makeFnJS(operandFnJS: string): string {
      throw new Error("implement me");
    }

    public evaluate(context: Lookup<any> = null): Dataset {
      var mySet: Set = this.operand.getFn()(context);
      return mySet.label(this.name);
    }

    // UNARY
  }

  Expression.register(LabelExpression);
}
