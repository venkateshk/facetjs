module Expressions {
  export class LessThanExpression extends BinaryExpression {
    static fromJS(parameters: ExpressionJS): LessThanExpression {
      return new LessThanExpression(BinaryExpression.jsToValue(parameters));
    }

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this._ensureOp("lessThan");
      this._checkTypeOf('lhs', 'NUMBER');
      this._checkTypeOf('rhs', 'NUMBER');
      this.type = 'BOOLEAN';
    }

    public toString(): string {
      return this.lhs.toString() + ' < ' + this.rhs.toString();
    }

    protected _makeFn(lhsFn: Function, rhsFn: Function): Function {
      return (d: Datum) => lhsFn(d) < rhsFn(d);
    }

    protected _makeFnJS(lhsFnJS: string, rhsFnJS: string): string {
      return '(' + lhsFnJS + '<' + rhsFnJS + ')';
    }

    // BINARY
  }

  Expression.register(LessThanExpression);
}
