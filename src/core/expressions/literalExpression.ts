module Core {
  export class LiteralExpression extends Expression {
    static fromJS(parameters: ExpressionJS): Expression {
      var value: ExpressionValue = {
        op: parameters.op,
        type: parameters.type
      };
      var v: any = parameters.value;
      if (isHigherObject(v)) {
        value.value = v;
      } else {
        value.value = valueFromJS(v, parameters.type);
      }
      return new LiteralExpression(value);
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
      this.type = getType(value);
      this.simple = true;
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
        js.type = (this.type.indexOf('SET/') === 0) ? 'SET' : this.type;
      } else {
        js.value = this.value;
      }
      return js;
    }

    public toString(): string {
      var value = this.value;
      if (value instanceof Dataset && value.basis()) {
        return 'facet()';
      } else if (this.type === 'STRING') {
        return JSON.stringify(value);
      } else {
        return String(value);
      }
    }

    public getFn(): ComputeFn {
      var value = this.value;
      return () => value;
    }

    public getJSExpression(): string {
      return JSON.stringify(this.value); // ToDo: what to do with higher objects?
    }

    public getSQL(): string {
      var value = this.value;
      switch (this.type) {
        case 'STRING':
          return JSON.stringify(value);

        case 'BOOLEAN':
          return String(value).toUpperCase();

        case 'NUMBER':
          return String(value);

        case 'NUMBER_RANGE':
          return String(value.start) + '/' + String(value.end);

        case 'TIME':
          return dateToSQL(<Date>value);

        case 'TIME_RANGE':
          return dateToSQL(value.start) + '/' + dateToSQL(value.end);

        case 'SET/STRING':
          return '(' + (<Set>value).getValues().map((v: string) => JSON.stringify(v)).join(',') + ')';

        default:
          throw new Error("currently unsupported type: " + this.type);
      }
    }

    public equals(other: LiteralExpression): boolean {
      if (!super.equals(other) || this.type !== other.type) return false;
      if (this.value && this.value.equals) {
        return this.value.equals(other.value);
      } else {
        return this.value === other.value;
      }
    }

    public getReferences(): string[] {
      return [];
    }

    public every(iter: BooleanExpressionIterator): boolean {
      return iter(this) !== false;
    }

    public forEach(iter: VoidExpressionIterator): void {
      iter(this);
    }

    public isRemote(): boolean {
      return this.value instanceof Dataset && this.value.source !== 'native';
    }

    public mergeAnd(exp: Expression): Expression {
      if (this.value === false) {
        return this;
      } else if (this.value === true) {
        return exp;
      } else {
        return null;
      }
    }

    public _fillRefSubstitutions(typeContext: FullType, alterations: Alteration[]): FullType {
      if (this.type == 'DATASET') {
        var newTypeContext = (<Dataset>this.value).getFullType();
        newTypeContext.parent = typeContext;
        return newTypeContext;
      } else {
        return { type: this.type };
      }
    }

    public _computeNativeResolved(queries: any[]): any {
      var value = this.value;
      if (value instanceof RemoteDataset) {
        if (queries) queries.push(value.getQueryAndPostProcess().query);
        return value.simulate();
      } else {
        return this.value;
      }
    }

    public _computeResolved(): Q.Promise<any> {
      var value = this.value;
      if (value instanceof RemoteDataset) {
        return value.queryValues();
      } else {
        return Q(this.value);
      }
    }
  }

  Expression.FALSE = <LiteralExpression>(new LiteralExpression({op: 'literal', value: false}));
  Expression.TRUE = <LiteralExpression>(new LiteralExpression({op: 'literal', value: true}));

  Expression.register(LiteralExpression);
}
