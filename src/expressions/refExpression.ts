module Facet {
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
  };

  export class RefExpression extends Expression {
    static NAME_REGEXP = /^(\^*)([a-z_]\w*)$/i;

    static fromJS(parameters: ExpressionJS): RefExpression {
      return new RefExpression(<any>parameters);
    }

    public generations: string;
    public name: string;
    public remote: string[];

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
        if (!hasOwnProperty(possibleTypes, parameters.type)) {
          throw new TypeError("unsupported type '" + parameters.type + "'");
        }
        this.type = parameters.type;
      }
      if (parameters.remote) this.remote = parameters.remote;
      this.simple = true;
    }

    public valueOf(): ExpressionValue {
      var value = super.valueOf();
      value.name = this.generations + this.name;
      if (this.type) value.type = this.type;
      if (this.remote) value.remote = this.remote;
      return value;
    }

    public toJS(): ExpressionJS {
      var js = super.toJS();
      js.name = this.generations + this.name;
      if (this.type) js.type = this.type;
      return js;
    }

    public toString(): string {
      //var remote = this.remote || [];
      return '$' + this.generations + this.name + (this.type ? ':' + this.type : ''); // + `#[${remote.join(',')}]`;
    }

    public getFn(): ComputeFn {
      if (this.generations.length) throw new Error("can not call getFn on unresolved expression");
      var name = this.name;
      return (d: Datum) => {
        if (hasOwnProperty(d, name)) {
          return d[name];
        } else if (d.$def && hasOwnProperty(d.$def, name)) {
          return d.$def[name];
        } else {
          return null;
        }
      }
    }

    public getJSExpression(): string {
      if (this.generations.length) throw new Error("can not call getJSExpression on unresolved expression");
      return 'd.' + this.name;
    }

    public getSQL(dialect: SQLDialect, minimal: boolean = false): string {
      if (this.generations.length) throw new Error("can not call getSQL on unresolved expression");
      return '`' + this.name + '`';
    }

    public equals(other: RefExpression): boolean {
      return super.equals(other) &&
        this.name === other.name &&
        this.generations === other.generations;
    }

    public isRemote(): boolean {
      return Boolean(this.remote && this.remote.length);
    }

    public _fillRefSubstitutions(typeContext: FullType, indexer: Indexer, alterations: Alterations): FullType {
      var myIndex = indexer.index;
      indexer.index++;
      var numGenerations = this.generations.length;

      // Step the parentContext back; once for each generation
      var myTypeContext = typeContext;
      while (numGenerations--) {
        myTypeContext = myTypeContext.parent;
        if (!myTypeContext) throw new Error('went too deep on ' + this.toString());
      }

      // Look for the reference in the parent chain
      var genBack = 0;
      while (myTypeContext && !myTypeContext.datasetType[this.name]) {
        myTypeContext = myTypeContext.parent;
        genBack++;
      }
      if (!myTypeContext) {
        throw new Error('could not resolve ' + this.toString());
      }

      var myFullType = myTypeContext.datasetType[this.name];

      var myType = myFullType.type;
      var myRemote = myFullType.remote;

      if (this.type && this.type !== myType) {
        throw new TypeError("type mismatch in " + this.toString() + " (has: " + this.type + " needs: " + myType + ")");
      }

      // Check if it needs to be replaced
      if (!this.type || genBack > 0 || String(this.remote) !== String(myRemote)) {
        var newGenerations = this.generations + repeat('^', genBack);
        alterations[myIndex] = new RefExpression({
          op: 'ref',
          name: newGenerations + this.name,
          type: myType,
          remote: myRemote
        })
      }

      if (myType === 'DATASET') {
        return {
          parent: typeContext,
          type: 'DATASET',
          datasetType: myFullType.datasetType,
          remote: myFullType.remote
        };
      }

      return myFullType;
    }
  }

  Expression.register(RefExpression);
}
