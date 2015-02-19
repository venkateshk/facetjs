module Core {
  export class RefExpression extends Expression {
    static NAME_REGEXP = /^(\^*)([a-z_]\w*)$/i;

    static fromJS(parameters: ExpressionJS): RefExpression {
      return new RefExpression(<any>parameters);
    }

    public generations: string;
    public name: string;

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this._ensureOp("ref");
      var match = parameters.name.match(RefExpression.NAME_REGEXP);
      if (match) {
        this.generations = match[1];
        this.name = match[2];
      } else {
        throw new Error("invalid name '" + parameters.name + "'");
      }
      if (typeof this.name !== 'string' || this.name.length === 0) {
        throw new TypeError("must have a nonempty `name`");
      }
      if (parameters.type) {
        if (possibleTypes.indexOf(parameters.type) === -1) {
          throw new TypeError('unsupported type ' + parameters.type);
        }
        this.type = parameters.type;
      }
    }

    public valueOf(): ExpressionValue {
      var value = super.valueOf();
      value.name = this.generations + this.name;
      if (this.type) value.type = this.type;
      return value;
    }

    public toJS(): ExpressionJS {
      var js = super.toJS();
      js.name = this.generations + this.name;
      if (this.type) js.type = this.type;
      return js;
    }

    public toString(): string {
      return '$' + this.generations + this.name;
    }

    public equals(other: RefExpression): boolean {
      return super.equals(other) &&
        this.name === other.name &&
        this.generations === other.generations;
    }

    public getReferences(): string[] {
      return [this.toString()];
    }

    public getFn(): Function {
      var len = this.generations.length;
      var name = this.name;
      return (d: Datum) => {
        for (var i = 0; i < len; i++) d = Object.getPrototypeOf(d);
        return d[name];
      }
    }

    public _getRawFnJS(): string {
      var gen = this.generations;
      return gen.replace(/\^/g, "Object.getPrototypeOf(") + 'd.' + this.name + gen.replace(/\^/g, ")");
    }
  }

  Expression.register(RefExpression);
}
