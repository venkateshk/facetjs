module Core {
  export class OrExpression extends NaryExpression {
    static fromJS(parameters: ExpressionJS): OrExpression {
      return new OrExpression(NaryExpression.jsToValue(parameters));
    }

    static _mergeExpressions(expressions: Expression[]): Expression {
      return expressions.reduce(function(expression, reducedExpression) {
        if (typeof reducedExpression === 'undefined') return expression;
        if (reducedExpression === null) return null;
        if (reducedExpression instanceof LiteralExpression) {
          if (reducedExpression.value === true) {
            return reducedExpression;
          } else if (reducedExpression.value === false) {
            return expression;
          }
        }
        return expression.mergeOr(reducedExpression);
      });
    }

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this._ensureOp("or");
      this._checkTypeOfOperands('BOOLEAN');
      this.type = 'BOOLEAN';
    }

    public toString(): string {
      return '(' + this.operands.map((operand) => operand.toString()).join('or') + ')';
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
        if (simplifiedOperands[i].isOp('or')) {
          mergedSimplifiedOperands = mergedSimplifiedOperands.concat((<OrExpression>simplifiedOperands[i]).operands);
        } else {
          mergedSimplifiedOperands.push(simplifiedOperands[i]);
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
        mergedExpression = OrExpression._mergeExpressions(groupedOperands[sortedReferenceGroups[k]]);
        if (mergedExpression === null) {
          finalOperands = finalOperands.concat(groupedOperands[sortedReferenceGroups[k]]);
        } else {
          finalOperands.push(mergedExpression);
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

    protected _makeFn(operandFns: ComputeFn[]): ComputeFn {
      throw new Error("should never be called directly");
    }

    protected _makeFnJS(operandFnJSs: string[]): string {
      throw new Error("should never be called directly");
    }

    // NARY
  }

  Expression.register(OrExpression);
}
