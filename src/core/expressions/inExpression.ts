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
          case 'TIME_RANGE':
          case 'NUMBER_RANGE':
          case 'SET':
            var intersect = (<LiteralExpression>this.rhs).value.intersect((<LiteralExpression>exp.rhs).value);
            if (intersect === null) return Expression.FALSE;

            return new InExpression({
              op: 'in',
              lhs: this.lhs,
              rhs: new LiteralExpression({
                op: 'literal',
                value: intersect
              })
            }).simplify();
        }
        return null;
      }
      return exp;
    }

    public mergeOr(exp: Expression): Expression {
      if (!this.checkLefthandedness()) return null; //TODO Do something about A is B and C in A
      if (!checkArrayEquality(this.getReferences(), exp.getReferences())) return null;

      if (exp instanceof IsExpression) {
        return exp.mergeOr(this);
      } else if (exp instanceof InExpression) {
        if (!exp.checkLefthandedness()) return null;
        if (this.rhs.type !== exp.rhs.type) return Expression.FALSE;
        switch (this.rhs.type) {
          case 'TIME_RANGE':
          case 'NUMBER_RANGE':
          case 'SET':
            var intersect = (<LiteralExpression>this.rhs).value.union((<LiteralExpression>exp.rhs).value);
            if (intersect === null) return null;

            return new InExpression({
              op: 'in',
              lhs: this.lhs,
              rhs: new LiteralExpression({
                op: 'literal',
                value: intersect
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
