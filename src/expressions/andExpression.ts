module Facet {
  export class AndExpression extends NaryExpression {
    static fromJS(parameters: ExpressionJS): AndExpression {
      return new AndExpression(NaryExpression.jsToValue(parameters));
    }

    static mergeTimePart(andExpression: AndExpression): InExpression {
      var operands = andExpression.operands;
      if (operands.length !== 2) return null;
      var concreteExpression: Expression;
      var partExpression: Expression;
      var op0TimePart = operands[0].containsOp('timePart');
      var op1TimePart = operands[1].containsOp('timePart');
      if (op0TimePart === op1TimePart) return null;
      if (op0TimePart) {
        concreteExpression = operands[1];
        partExpression = operands[0];
      } else {
        concreteExpression = operands[0];
        partExpression = operands[1];
      }

      var lhs: Expression;
      var concreteRangeSet: Set;
      if (concreteExpression instanceof InExpression && concreteExpression.checkLefthandedness()) {
        lhs = concreteExpression.lhs;
        concreteRangeSet = Set.convertToSet((<LiteralExpression>concreteExpression.rhs).value);
      } else {
        return null;
      }

      var unitSmall: string;
      var unitBig: string;
      var timezone: Timezone;
      var values: number[];
      if (partExpression instanceof InExpression || partExpression instanceof IsExpression) {
        var partLhs = partExpression.lhs;
        var partRhs = partExpression.rhs;
        if (partLhs instanceof TimePartExpression && partRhs instanceof LiteralExpression) {
          var partUnits = partLhs.part.toLowerCase().split('_of_');
          unitSmall = partUnits[0];
          unitBig = partUnits[1];
          timezone = partLhs.timezone;
          values = Set.convertToSet(partRhs.value).getElements();
        } else {
          return null;
        }
      } else {
        return null;
      }

      var smallTimeMover = <Chronology.TimeMover>(<any>Chronology)[unitSmall];
      var bigTimeMover = <Chronology.TimeMover>(<any>Chronology)[unitBig];

      var concreteExtent: Range<any> = concreteRangeSet.extent();
      var start = concreteExtent.start;
      var end = concreteExtent.end;

      var ranges: TimeRange[] = [];
      var iter = bigTimeMover.floor(start, timezone);
      while (iter <= end) {
        for (var i = 0; i < values.length; i++) {
          var subIter = smallTimeMover.move(iter, timezone, values[i]);
          ranges.push(new TimeRange({
            start: subIter,
            end: smallTimeMover.move(subIter, timezone, 1)
          }));
        }
        iter = bigTimeMover.move(iter, timezone, 1);
      }

      return <InExpression>lhs.in({
        op: 'literal',
        value: concreteRangeSet.intersect(Set.fromJS({
          setType: 'TIME_RANGE',
          elements: ranges
        }))
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
        var mergedExpressions = multiMerge(groupedOperands[sortedReferenceGroups[k]], (a, b) => {
          return a ? a.mergeAnd(b) : null;
        });
        if (mergedExpressions.length === 1) {
          finalOperands.push(mergedExpressions[0]);
        } else {
          finalOperands.push(new AndExpression({
            op: 'and',
            operands: mergedExpressions
          }));
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
