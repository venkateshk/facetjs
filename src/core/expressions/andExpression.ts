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

    public simplify(): Expression {
      if (this.simple) return this;

      var finalOperands: Expression[];
      var groupedOperands: { [key: string]: Expression[]; };
      var mergedExpression: Expression;
      var mergedSimplifiedOperands: Expression[];
      var referenceGroup: string;
      var simplifiedOperands: Expression[];
      var sortedReferenceGroups: string[];
      var thisOperand: Expression;

      mergedSimplifiedOperands = [];
      simplifiedOperands = this.operands.map((operand) => operand.simplify());

      for (var i = 0; i < simplifiedOperands.length; i++) {
        var simplifiedOperand = simplifiedOperands[i];
        if (simplifiedOperand instanceof AndExpression) {
          mergedSimplifiedOperands = mergedSimplifiedOperands.concat((simplifiedOperand).operands);
        } else {
          mergedSimplifiedOperands.push(simplifiedOperand);
        }
      }

      groupedOperands = {};

      for (var j = 0; j < mergedSimplifiedOperands.length; j++) {
        thisOperand = mergedSimplifiedOperands[j];
        referenceGroup = thisOperand.getReferences().toString();

        if (groupedOperands[referenceGroup]) {
          groupedOperands[referenceGroup].push(thisOperand);
        } else {
          groupedOperands[referenceGroup] = [thisOperand];
        }
      }

      finalOperands = [];
      sortedReferenceGroups = Object.keys(groupedOperands).sort();

      for (var k = 0; k < sortedReferenceGroups.length; k++) {
        mergedExpression = AndExpression._mergeExpressions(groupedOperands[sortedReferenceGroups[k]]);
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
