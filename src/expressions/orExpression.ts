module Facet {
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
      return '(' + this.operands.map((operand) => operand.toString()).join(' or ') + ')';
    }

    protected _getFnHelper(operandFns: ComputeFn[]): ComputeFn {
      return (d: Datum) => {
        var res = false;
        for (var i = 0; i < operandFns.length; i++) {
          res = res || operandFns[i](d);
        }
        return res;
      }
    }

    protected _getJSExpressionHelper(operandJSExpressions: string[]): string {
      return '(' + operandJSExpressions.join('||')  + ')';
    }

    protected _getSQLHelper(operandSQLs: string[], dialect: SQLDialect, minimal: boolean): string {
      return '(' + operandSQLs.join(' OR ')  + ')';
    }

    public simplify(): Expression {
      if (this.simple) return this;

      var simplifiedOperands = this.operands.map((operand) => operand.simplify());

      var mergedSimplifiedOperands: Expression[] = [];
      for (var i = 0; i < simplifiedOperands.length; i++) {
        if (simplifiedOperands[i].isOp('or')) {
          mergedSimplifiedOperands = mergedSimplifiedOperands.concat((<OrExpression>simplifiedOperands[i]).operands);
        } else {
          mergedSimplifiedOperands.push(simplifiedOperands[i]);
        }
      }

      var groupedOperands: Lookup<Expression[]> = {};
      for (var j = 0; j < mergedSimplifiedOperands.length; j++) {
        var thisOperand = mergedSimplifiedOperands[j];
        var referenceGroup = thisOperand.getFreeReferences().toString();

        if (groupedOperands[referenceGroup]) {
          groupedOperands[referenceGroup].push(thisOperand);
        } else {
          groupedOperands[referenceGroup] = [thisOperand];
        }
      }

      var sortedReferenceGroups = Object.keys(groupedOperands).sort();
      var finalOperands: Expression[] = [];
      for (var k = 0; k < sortedReferenceGroups.length; k++) {
        var mergedExpressions = multiMerge(groupedOperands[sortedReferenceGroups[k]], (a, b) => {
          return a ? a.mergeOr(b) : null;
        });
        if (mergedExpressions.length === 1) {
          finalOperands.push(mergedExpressions[0]);
        } else {
          finalOperands.push(new OrExpression({
            op: 'or',
            operands: mergedExpressions
          }));
        }
      }

      finalOperands = finalOperands.filter((operand) => !(operand.isOp('literal') && (<LiteralExpression>operand).value === false));

      if (finalOperands.some((operand) => operand.isOp('literal') && (<LiteralExpression>operand).value === true)) {
        return Expression.TRUE;
      }

      if (finalOperands.length === 0) {
        return Expression.FALSE;
      } else if (finalOperands.length === 1) {
        return finalOperands[0];
      } else {
        var simpleValue = this.valueOf();
        simpleValue.operands = finalOperands;
        simpleValue.simple = true;
        return new OrExpression(simpleValue);
      }
    }
  }

  Expression.register(OrExpression);
}
