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

    protected _makeFn(operandFns: Function[]): Function {
      return (d: Datum) => {
        var res = 0;
        for (var i = 0; i < operandFns.length; i++) {
          res += operandFns[i](d) || 0;
        }
        return res;
      }
    }

    protected _makeFnJS(operandFnJSs: string[]): string {
      return '(' + operandFnJSs.join('+')  + ')';
    }

    // NARY
  }

  Expression.register(AddExpression);
}
