module Core {
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
      return 'and(' + this.operands.map((operand) => operand.toString()) + ')';
    }

    public simplify(): Expression { //TODO
      var simplifiedOperands: Expression[] = this.operands.map((operand) => operand.simplify());

      var mergedSimplifiedOperands: Expression[] = [];
      for (var i = 0; i < simplifiedOperands.length; i++) {
        if (simplifiedOperands[i].isOp('and')) {
          mergedSimplifiedOperands = mergedSimplifiedOperands.concat((<AndExpression>simplifiedOperands[i]).operands);
        } else {
          mergedSimplifiedOperands.push(simplifiedOperands[i]);
        }
      }

      var groupedOperands: { [key: string]: Expression[]; } = {};

      for (var j = 0; j < mergedSimplifiedOperands.length; j++) {
        var thisOperand = mergedSimplifiedOperands[j];
        var referenceGroup = thisOperand.getReferences().toString();

        if (groupedOperands[referenceGroup]) {
          groupedOperands[referenceGroup].push(thisOperand);
        } else {
          groupedOperands[referenceGroup] = [thisOperand];
        }
      }

      var finalOperands: Expression[] = [];
      var sortedReferenceGroups = Object.keys(groupedOperands).sort();
      for (var k = 0; k < sortedReferenceGroups.length; k++) {
        if (groupedOperands[sortedReferenceGroups[k]].length > 1) {
          finalOperands.push(AndExpression._mergeExpressions(groupedOperands[sortedReferenceGroups[k]]));
        } else {
          finalOperands = finalOperands.concat(groupedOperands[sortedReferenceGroups[k]]);
        }
      }

      if (finalOperands.some((operand) => operand.isOp('literal') && (<LiteralExpression>operand).value === false)) {
        return new LiteralExpression({
          op: 'literal',
          value: false
        });
      }

      if (finalOperands.length === 1) {
        return finalOperands[0];
      }

      return new AndExpression({
        op: 'and',
        operands: finalOperands
      });
    }

    protected _makeFn(operandFns: Function[]): Function {
      throw new Error("should never be called directly");
    }

    protected _makeFnJS(operandFnJSs: string[]): string {
      throw new Error("should never be called directly");
    }

    // NARY
  }

  Expression.register(AndExpression);
}
