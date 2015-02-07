module Facet {
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

    protected _makeFn(lhsFn: Function, rhsFn: Function): Function {
      return (d: Datum) => rhsFn(d).indexOf(lhsFn(d)) > -1;
    }

    protected _makeFnJS(lhsFnJS: string, rhsFnJS: string): string {
      throw new Error("implement me!");
    }

    // BINARY
  }

  Expression.register(InExpression);
}
