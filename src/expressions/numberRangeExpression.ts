module Facet {
  export class NumberRangeExpression extends BinaryExpression {
    static fromJS(parameters: ExpressionJS): NumberRangeExpression {
      return new NumberRangeExpression(BinaryExpression.jsToValue(parameters));
    }

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this._ensureOp("numberRange");
      var lhs = this.lhs;
      var rhs = this.rhs;
      if (!((lhs.type === 'NUMBER' && rhs.canHaveType('NUMBER')) || (rhs.type === 'NUMBER' && lhs.canHaveType('NUMBER')))) {
        throw new TypeError("unbalanced type attributes to numberRange");
      }
      this.type = 'NUMBER_RANGE';
    }

    public toString(): string {
      return '[' + this.lhs.toString() + ', ' + this.rhs.toString() + ')';
    }

    protected _makeFn(lhsFn: Function, rhsFn: Function): Function {
      return (d: Datum) => new NumberRange({
        start: lhsFn(d),
        end: rhsFn(d)
      });
    }

    protected _makeFnJS(lhsFnJS: string, rhsFnJS: string): string {
      throw new Error("implement me!");
    }

    // BINARY
  }

  Expression.register(NumberRangeExpression);
}
