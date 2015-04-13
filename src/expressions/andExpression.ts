module Facet {
  export class AndExpression extends NaryExpression {
    static fromJS(parameters: ExpressionJS): AndExpression {
      return new AndExpression(NaryExpression.jsToValue(parameters));
    }

    static _mergeExpressions(expressions: Expression[]): Expression {
      return expressions.reduce(function(expression, reducedExpression) {
        if (typeof reducedExpression === 'undefined') return expression;
        if (reducedExpression === null) return null;
        if (reducedExpression instanceof LiteralExpression) {
          if (reducedExpression.value === true) {
            return expression;
          } else if (reducedExpression.value === false) {
            return reducedExpression;
          }
        }
        return expression.mergeAnd(reducedExpression);
      });
    }

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this._ensureOp("and");
      this._checkTypeOfOperands('BOOLEAN');
      this.type = 'BOOLEAN';
    }

    public toString(): string {
      return '(' + this.operands.map((operand) => operand.toString()).join(' and ') + ')';
    }

    protected _getFnHelper(operandFns: ComputeFn[]): ComputeFn {
      return (d: Datum) => {
        var res = true;
        for (var i = 0; i < operandFns.length; i++) {
          res = res && operandFns[i](d);
        }
        return res;
      }
    }

    protected _getJSExpressionHelper(operandJSExpressions: string[]): string {
      return '(' + operandJSExpressions.join('&&')  + ')';
    }

    protected _getSQLHelper(operandSQLs: string[], dialect: SQLDialect, minimal: boolean): string {
      return '(' + operandSQLs.join(' AND ')  + ')';
    }

    public simplify(): Expression {
      if (this.simple) return this;

      var simplifiedOperands = this.operands.map((operand) => operand.simplify());

      var mergedSimplifiedOperands: Expression[] = [];
      for (var i = 0; i < simplifiedOperands.length; i++) {
        var simplifiedOperand = simplifiedOperands[i];
        if (simplifiedOperand instanceof AndExpression) {
          mergedSimplifiedOperands = mergedSimplifiedOperands.concat(simplifiedOperand.operands);
        } else {
          mergedSimplifiedOperands.push(simplifiedOperand);
        }
      }

      var groupedOperands: Lookup<Expression[]> = {};
      for (var j = 0; j < mergedSimplifiedOperands.length; j++) {
        var thisOperand = mergedSimplifiedOperands[j];
        var referenceGroup = thisOperand.getFreeReferences().toString();

        if (hasOwnProperty(groupedOperands, referenceGroup)) {
          groupedOperands[referenceGroup].push(thisOperand);
        } else {
          groupedOperands[referenceGroup] = [thisOperand];
        }
      }

      var sortedReferenceGroups = Object.keys(groupedOperands).sort();
      var finalOperands: Expression[] = [];
      for (var k = 0; k < sortedReferenceGroups.length; k++) {
        var mergedExpression = AndExpression._mergeExpressions(groupedOperands[sortedReferenceGroups[k]]);
        if (mergedExpression === null) {
          finalOperands = finalOperands.concat(groupedOperands[sortedReferenceGroups[k]]);
        } else {
          finalOperands.push(mergedExpression);
        }
      }

      finalOperands = finalOperands.filter((operand) => !(operand.isOp('literal') && (<LiteralExpression>operand).value === true));

      if (finalOperands.some((operand) => operand.isOp('literal') && (<LiteralExpression>operand).value === false)) {
        return Expression.FALSE;
      }

      if (finalOperands.length === 0) {
        return Expression.TRUE;
      } else if (finalOperands.length === 1) {
        return finalOperands[0];
      } else {
        var simpleValue = this.valueOf();
        simpleValue.operands = finalOperands;
        simpleValue.simple = true;
        return new AndExpression(simpleValue);
      }
    }

    public separateViaAnd(refName: string): Separation {
      if (typeof refName !== 'string') throw new Error('must have refName');
      //if (!this.simple) return this.simplify().separateViaAnd(refName);

      var includedExpressions: Expression[] = [];
      var excludedExpressions: Expression[] = [];
      var operands = this.operands;
      for (var i = 0; i < operands.length; i++) {
        var operand = operands[i];
        var sep = operand.separateViaAnd(refName);
        if (sep === null) return null;
        includedExpressions.push(sep.included);
        excludedExpressions.push(sep.excluded);
      }

      return {
        included: new AndExpression({op: 'and', operands: includedExpressions}).simplify(),
        excluded: new AndExpression({op: 'and', operands: excludedExpressions}).simplify()
      };
    }
  }

  Expression.register(AndExpression);
}
