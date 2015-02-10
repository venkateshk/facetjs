module Core {
  export class ConcatExpression extends NaryExpression {
    static fromJS(parameters: ExpressionJS): ConcatExpression {
      return new ConcatExpression(NaryExpression.jsToValue(parameters));
    }

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this._ensureOp("concat");
      this._checkTypeOfOperands('STRING');
      this.type = 'STRING';
    }

    public toString(): string {
      return 'concat(' + this.operands.map((operand) => operand.toString()) + ')';
    }

    public simplify(): Expression {
      var simplifiedOperands = this.operands.map((operand) => operand.simplify());
      var hasLiteralOperandsOnly = simplifiedOperands.every((operand) => operand.isOp('literal'));

      if (hasLiteralOperandsOnly) {
        return new LiteralExpression({
          op: 'literal',
          value: this._makeFn(simplifiedOperands.map((operand) => operand.getFn()))()
        });
      }

      var i = 0;
      while(i < simplifiedOperands.length - 2) {
        if (simplifiedOperands[i].isOp('literal') && simplifiedOperands[i + 1].isOp('literal')) {
          var mergedValue = (<LiteralExpression>simplifiedOperands[i]).value + (<LiteralExpression>simplifiedOperands[i + 1]).value;
          simplifiedOperands.splice(i, 2, new LiteralExpression({
            op: 'literal',
            value: mergedValue
          }));
        } else {
          i++;
        }
      }

      var value = this.valueOf();
      value.operands = simplifiedOperands;
      return new ConcatExpression(value);
    }

    protected _makeFn(operandFns: Function[]): Function {
      return (d: Datum) => {
        return operandFns.map((operandFn) => operandFn(d)).join('');
      }
    }

    protected _makeFnJS(operandFnJSs: string[]): string {
      return '(' + operandFnJSs.join('+') + ')';
    }

    // NARY
  }

  Expression.register(ConcatExpression);

}
