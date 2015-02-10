module Core {
  export class InExpression extends BinaryExpression {
    static fromJS(parameters: ExpressionJS): InExpression {
      return new InExpression(BinaryExpression.jsToValue(parameters));
    }

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this._ensureOp("in");
      var lhs = this.lhs;
      var rhs = this.rhs;

      if(!(rhs.canHaveType('SET')
        || (lhs.canHaveType('NUMBER') && rhs.canHaveType('NUMBER_RANGE'))
        || (lhs.canHaveType('TIME') && rhs.canHaveType('TIME_RANGE')))) {
        throw new TypeError('in expression has a bad type combo');
      }

      this.type = 'BOOLEAN';
    }

    public toString(): string {
      return this.lhs.toString() + ' = ' + this.rhs.toString();
    }

    public mergeAnd(exp: Expression): Expression {
      if (!this.checkLefthandedness()) return null; //TODO Do something about A is B and C in A
      if (!checkArrayEquality(this.getReferences(), exp.getReferences())) return null;

      if (exp instanceof IsExpression) {
        return exp.mergeAnd(this);
      } else if (exp instanceof InExpression) {
        if (!exp.checkLefthandedness()) return null;
        if (this.rhs.type !== exp.rhs.type) return Expression.FALSE;
        switch (this.rhs.type) {
          case 'NUMBER_RANGE':
            return new InExpression({
              op: 'in',
              lhs: this.lhs,
              rhs: new NumberRangeExpression({
                op: 'numberRange',
                lhs: new LiteralExpression({
                  op: 'literal',
                  value: Math.max(
                    (<LiteralExpression>(<NumberRangeExpression>this.rhs).lhs).value
                    (<LiteralExpression>(<NumberRangeExpression>exp.rhs).lhs).value
                  )
                }),
                rhs: new LiteralExpression({
                  op: 'literal',
                  value: Math.min(
                    (<LiteralExpression>(<NumberRangeExpression>this.rhs).rhs).value
                    (<LiteralExpression>(<NumberRangeExpression>exp.rhs).rhs).value
                  )
                })
              })
            }).simplify();
          case 'TIME_RANGE': // intentional fall through
            return new InExpression({
              op: 'in',
              lhs: this.lhs,
              rhs: new TimeRangeExpression({
                op: 'numberRange',
                lhs: new LiteralExpression({
                  op: 'literal',
                  value: Math.max(
                    (<LiteralExpression>(<TimeRangeExpression>this.rhs).lhs).value
                    (<LiteralExpression>(<TimeRangeExpression>exp.rhs).lhs).value
                  )
                }),
                rhs: new LiteralExpression({
                  op: 'literal',
                  value: Math.min(
                    (<LiteralExpression>(<TimeRangeExpression>this.rhs).rhs).value
                    (<LiteralExpression>(<TimeRangeExpression>exp.rhs).rhs).value
                  )
                })
              })
            }).simplify();
          case 'SET':
            return new InExpression({
              op: 'in',
              lhs: this.lhs,
              rhs: new LiteralExpression({
                op: 'literal',
                value: (<LiteralExpression>this.rhs).value.intersect((<LiteralExpression>exp.rhs).value)
              })
            }).simplify();
        }
        return null;
      }
      return exp;
    }

    protected _makeFn(lhsFn: Function, rhsFn: Function): Function {
      return (d: Datum) => rhsFn(d).test(lhsFn(d));
    }

    protected _makeFnJS(lhsFnJS: string, rhsFnJS: string): string {
      throw new Error("implement me!");
    }

    // BINARY
  }

  Expression.register(InExpression);
}
