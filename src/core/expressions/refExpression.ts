module Core {
  function repeat(str: string, times: number): string {
    return new Array(times + 1).join(str);
  }

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

    public _fillRefSubstitutions(parentContext: any, alterations: Alteration[]): any {
      var numGenerations = this.generations.length;

      // Step the parentContext back; once for each generation
      while (numGenerations--) {
        parentContext = parentContext.$parent;
        if (!parentContext) new Error('went too deep on `' + this.generations + this.name + '`');
      }

      // Look for the reference in the parent chain
      var genBack = 0;
      while (parentContext && !parentContext[this.name]) {
        parentContext = parentContext.$parent;
        genBack++;
      }
      if (!parentContext) throw new Error('could not resolve ' + this.toString());

      var contextType = parentContext[this.name];
      var myType: string = (typeof contextType === 'object') ? 'DATASET' : contextType;

      if (this.type && this.type !== myType) {
        throw new TypeError("type mismatch in " + this.toString() + " (has: " + this.type + " needs: " + myType + ")");
      }

      // Check if it needs to be replaced
      if (!this.type || genBack > 0) {
        var newGenerations = this.generations + repeat('^', genBack);
        alterations.push({
          from: this,
          to: new RefExpression({
            op: 'ref',
            name: newGenerations + this.name,
            type: myType
          })
        })
      }

      return contextType;
    }
  }

  Expression.register(RefExpression);
}
