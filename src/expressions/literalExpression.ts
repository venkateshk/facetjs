module Expressions {

  export class LiteralExpression extends Expression {
    static fromJS(parameters: ExpressionJS): Expression {
      return new LiteralExpression(<any>parameters);
    }

    public value: any;

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      var value = parameters.value;
      this.value = value;
      this._ensureOp("literal");
      if (typeof this.value === 'undefined') {
        throw new TypeError("must have a `value`")
      }
      var typeofValue = typeof value;
      if (typeofValue === 'object') {
        if (value === null) {
          this.type = 'NULL';
        } else if (value.toISOString) {
          this.type = 'TIME';
        } else {
          this.type = value.constructor.type;
          if (!this.type) throw new Error("can not have an object without a type");
        }
      } else {
        if (typeofValue !== 'boolean' && typeofValue !== 'number' && typeofValue !== 'string') {
          throw new TypeError('unsupported type literal type ' + typeofValue);
        }
        this.type = typeofValue.toUpperCase();
      }
    }

    public valueOf(): ExpressionValue {
      var value = super.valueOf();
      value.value = this.value;
      if (this.type) value.type = this.type;
      return value;
    }

    public toJS(): ExpressionJS {
      var js = super.toJS();
      if (this.value && this.value.toJS) {
        js.value = this.value.toJS();
        js.type = this.type;
      } else {
        js.value = this.value;
      }
      return js;
    }

    public toString(): string {
      return String(this.value);
    }

    public equals(other: LiteralExpression): boolean {
      return super.equals(other) &&
        this.value === other.value;
    }

    public getReferences(): string[] {
      return [];
    }

    public getFn(): Function {
      var value = this.value;
      return () => value;
    }

    public _getRawFnJS(): string {
      return JSON.stringify(this.value); // ToDo: what to do with higher objects?
    }
  }

  Expression.register(LiteralExpression);

  Expression.FALSE = <LiteralExpression>(new LiteralExpression({op: 'literal', value: false}));
  Expression.TRUE = <LiteralExpression>(new LiteralExpression({op: 'literal', value: true}));
}
