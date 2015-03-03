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
      } else {
        return String(value);
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

    public getFn(): Function {
      var value = this.value;
      return () => value;
    }

    public every(iter: BooleanExpressionIterator): boolean {
      return iter(this);
    }

    public some(iter: BooleanExpressionIterator): boolean {
      return iter(this);
    }

    public isRemote(): boolean {
      return this.value instanceof Dataset && this.value.source !== 'native';
    }

    public _getRawFnJS(): string {
      return JSON.stringify(this.value); // ToDo: what to do with higher objects?
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

    public _fillRefSubstitutions(typeContext: any, alterations: Alteration[]): any {
      if (this.type == 'DATASET') {
        var newTypeContext = this.value.getType();
        newTypeContext.$parent = typeContext;
        newTypeContext.$remote = this.isRemote();
        return newTypeContext;
      } else {
        return this.type;
      }
    }

    public computeNativeResolved(): any {
      return this.value;
    }

    public simulateResolved(): any {
      return this.value;
    }
  }

  Expression.FALSE = <LiteralExpression>(new LiteralExpression({op: 'literal', value: false}));
  Expression.TRUE = <LiteralExpression>(new LiteralExpression({op: 'literal', value: true}));

  Expression.register(LiteralExpression);
}
