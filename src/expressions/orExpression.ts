module Core {
  export class OrExpression extends NaryExpression {
    static fromJS(parameters: ExpressionJS): OrExpression {
      return new OrExpression(NaryExpression.jsToValue(parameters));
    }

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this._ensureOp("or");
      this._checkTypeOfOperands('BOOLEAN');
      this.type = 'BOOLEAN';
    }

    public toString(): string {
      return '(' + this.operands.map((operand) => operand.toString()).join('or') + ')';
    }

    public simplify(): Expression {
      return this //TODO
    }

    protected _makeFn(operandFns: Function[]): Function {
      throw new Error("should never be called directly");
    }

    protected _makeFnJS(operandFnJSs: string[]): string {
      throw new Error("should never be called directly");
    }

    // NARY
  }

  Expression.register(OrExpression);
}
