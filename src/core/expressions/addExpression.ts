module Core {
  export class AddExpression extends NaryExpression {
    static fromJS(parameters: ExpressionJS): AddExpression {
      return new AddExpression(NaryExpression.jsToValue(parameters));
    }

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this._ensureOp("add");
      this._checkTypeOfOperands('NUMBER');
      this.type = 'NUMBER';
    }

    public toString(): string {
      return '(' + this.operands.map((operand) => operand.toString()).join(' + ') + ')';
    }

    protected _getFnHelper(operandFns: ComputeFn[]): ComputeFn {
      return (d: Datum) => {
        var res = 0;
        for (var i = 0; i < operandFns.length; i++) {
          res += operandFns[i](d) || 0;
        }
        return res;
      }
    }

    protected _getJSExpressionHelper(operandJSExpressions: string[]): string {
      return '(' + operandJSExpressions.join('+')  + ')';
    }

    protected _getSQLHelper(operandSQLs: string[]): string {
      return '(' + operandSQLs.join('+')  + ')';
    }
  }

  Expression.register(AddExpression);
}
