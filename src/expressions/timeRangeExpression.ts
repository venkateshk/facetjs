module Facet {
  export class TimeRangeExpression extends BinaryExpression {
    static fromJS(parameters: ExpressionJS): TimeRangeExpression {
      return new TimeRangeExpression(BinaryExpression.jsToValue(parameters));
    }

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this._ensureOp("timeRange");
      var lhs = this.lhs;
      var rhs = this.rhs;
      if (!((lhs.type === 'TIME' && rhs.canHaveType('TIME')) || (rhs.type === 'TIME' && lhs.canHaveType('TIME')))) {
        throw new TypeError("unbalanced type attributes to timeRange");
      }
      this.type = 'TIME_RANGE';
    }

    public toString(): string {
      return '[' + this.lhs.toString() + ', ' + this.rhs.toString() + ')';
    }

    protected _makeFn(lhsFn: Function, rhsFn: Function): Function {
      return (d: Datum) => new TimeRange({
        start: lhsFn(d),
        end: rhsFn(d)
      });
    }

    protected _makeFnJS(lhsFnJS: string, rhsFnJS: string): string {
      throw new Error("implement me!");
    }

    // BINARY
  }

  Expression.register(TimeRangeExpression);

}
