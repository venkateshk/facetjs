module Core {
  function repeat(str: string, times: number): string {
    return new Array(times + 1).join(str);
  }

  export var possibleTypes: Lookup<number> = {
    'NULL': 1,
    'BOOLEAN': 1,
    'NUMBER': 1,
    'TIME': 1,
    'STRING': 1,
    'NUMBER_RANGE': 1,
    'TIME_RANGE': 1,
    'SET': 1,
    'SET/NULL': 1,
    'SET/BOOLEAN': 1,
    'SET/NUMBER': 1,
    'SET/TIME': 1,
    'SET/STRING': 1,
    'SET/NUMBER_RANGE': 1,
    'SET/TIME_RANGE': 1,
    'DATASET': 1
  }

  export class RefExpression extends Expression {
    static NAME_REGEXP = /^(\^*)([a-z_]\w*)$/i;

    static fromJS(parameters: ExpressionJS): RefExpression {
      return new RefExpression(<any>parameters);
    }

    public generations: string;
    public name: string;
    public remote: boolean;

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
      this.remote = Boolean(parameters.remote);
      if (parameters.type) {
        if (!possibleTypes[parameters.type]) {
          throw new TypeError('unsupported type ' + parameters.type);
        }
        this.type = parameters.type;
      }
      this.simple = true;
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
      return '$' + this.generations + this.name + (this.type ? ':' + this.type : '');
    }

    public equals(other: RefExpression): boolean {
      return super.equals(other) &&
        this.name === other.name &&
        this.generations === other.generations;
    }

    public getReferences(): string[] {
      return [this.name];
    }

    public getFn(): Function {
      if (this.generations.length) throw new Error("can not call getFn on unresolved expression");
      var name = this.name;
      return (d: Datum) => {
        if (d.hasOwnProperty(name)) {
          return d[name];
        } else if (d.$def && d.$def.hasOwnProperty(name)) {
          return d.$def[name];
        } else {
          return null;
        }
      }
    }

    public _getRawFnJS(): string {
      if (this.generations.length) throw new Error("can not call getRawFnJS on unresolved expression");
      return 'd.' + this.name;
    }

    public isRemote(): boolean {
      return this.remote;
    }

    public _fillRefSubstitutions(typeContext: any, alterations: Alteration[]): any {
      var numGenerations = this.generations.length;

      // Step the parentContext back; once for each generation
      var myTypeContext = typeContext;
      while (numGenerations--) {
        myTypeContext = myTypeContext.$parent;
        if (!myTypeContext) throw new Error('went too deep on ' + this.toString());
      }

      // Look for the reference in the parent chain
      var genBack = 0;
      while (myTypeContext && !myTypeContext[this.name]) {
        myTypeContext = myTypeContext.$parent;
        genBack++;
      }
      if (!myTypeContext) {
        throw new Error('could not resolve ' + this.toString());
      }

      var contextType = myTypeContext[this.name];

      var myType: string = contextType;
      var myRemote: boolean = this.remote;
      if (typeof contextType === 'object') {
        myType = 'DATASET';
        myRemote = Boolean(contextType.$remote);
      }

      if (this.type && this.type !== myType) {
        throw new TypeError("type mismatch in " + this.toString() + " (has: " + this.type + " needs: " + myType + ")");
      }

      // Check if it needs to be replaced
      if (!this.type || genBack > 0 || this.remote !== myRemote) {
        var newGenerations = this.generations + repeat('^', genBack);
        alterations.push({
          from: this,
          to: new RefExpression({
            op: 'ref',
            name: newGenerations + this.name,
            type: myType,
            remote: myRemote
          })
        })
      }

      if (myType === 'DATASET') {
        // Set the new parent context correctly
        contextType = shallowCopy(contextType);
        contextType.$parent = typeContext;
      }

      return contextType;
    }
  }

  Expression.register(RefExpression);
}
