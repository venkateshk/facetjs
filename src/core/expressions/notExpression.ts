module Core {
  export class NotExpression extends UnaryExpression {
    static fromJS(parameters: ExpressionJS): NotExpression {
      return new NotExpression(UnaryExpression.jsToValue(parameters));
    }

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this._ensureOp("not");
      this._checkTypeOfOperand('BOOLEAN');
      this.type = 'BOOLEAN';
    }

    public toString(): string {
      return this.operand.toString() + '.not()';
    }

    protected _makeFn(operandFn: ComputeFn): ComputeFn {
      return (d: Datum) => !operandFn(d);
    }

    protected _makeFnJS(operandFnJS: string): string {
      return "!(" + operandFnJS + ")"
    }

    protected _specialSimplify(simpleOperand: Expression): Expression {
      if (simpleOperand instanceof NotExpression) {
        return simpleOperand.operand;
      }
      return null;
    }
  }

  Expression.register(NotExpression);
}
