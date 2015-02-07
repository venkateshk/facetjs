module Expressions {
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
      return 'add(' + this.operands.map((operand) => operand.toString()) + ')';
    }

    public simplify(): Expression {
      var newOperands: Expression[] = [];
      var literalValue: number = 0;
      for (var i = 0; i < this.operands.length; i++) {
        var simplifiedOperand: Expression = this.operands[i].simplify();
        if (simplifiedOperand.isOp('literal')) {
          literalValue += (<LiteralExpression>simplifiedOperand).value;
        } else {
          newOperands.push(simplifiedOperand);
        }
      }

      if (newOperands.length === 0) {
        return new LiteralExpression({ op: 'literal', value: literalValue });
      } else {
        if (literalValue) {
          newOperands.push(new LiteralExpression({ op: 'literal', value: literalValue }));
        }
        return new AddExpression({
          op: 'add',
          operands: newOperands
        })
      }
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
