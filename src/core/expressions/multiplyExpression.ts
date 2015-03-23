module Core {
  export class MultiplyExpression extends NaryExpression {
    static fromJS(parameters: ExpressionJS): MultiplyExpression {
      return new MultiplyExpression(NaryExpression.jsToValue(parameters));
    }

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this._ensureOp("multiply");
      this._checkTypeOfOperands('NUMBER');
      this.type = 'NUMBER';
    }

    public toString(): string {
      return '(' + this.operands.map((operand) => operand.toString()).join(' * ') + ')';
    }

    protected _getFnHelper(operandFns: ComputeFn[]): ComputeFn {
      return (d: Datum) => {
        var res = 1;
        for (var i = 0; i < operandFns.length; i++) {
          res *= operandFns[i](d) || 0;
        }
        return res;
      }
    }

    protected _getJSExpressionHelper(operandJSExpressions: string[]): string {
      return '(' + operandJSExpressions.join('*')  + ')';
    }

    protected _getSQLHelper(operandSQLs: string[]): string {
      return '(' + operandSQLs.join('*')  + ')';
    }
  }

  Expression.register(MultiplyExpression);
}
