module Core {
  export class AggregateExpression extends UnaryExpression {
    static fromJS(parameters: ExpressionJS): AggregateExpression {
      var value = UnaryExpression.jsToValue(parameters);
      value.fn = parameters.fn;
      if (parameters.attribute) {
        value.attribute = Expression.fromJSLoose(parameters.attribute);
      }
      return new AggregateExpression(value);
    }

    public fn: string;
    public attribute: Expression;

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this.fn = parameters.fn;
      this.attribute = parameters.attribute;
      this._ensureOp("aggregate");
      this._checkTypeOfOperand('DATASET');
      if (this.fn !== 'count' && !this.attribute) {
        throw new Error(this.fn + " aggregate must have an 'attribute'");
      }
      if (this.fn === 'group') {
        var attrType = this.attribute.type;
        this.type = attrType ? ('SET/' + attrType) : null;
      } else {
        this.type = 'NUMBER';
      }
    }

    public valueOf(): ExpressionValue {
      var value = super.valueOf();
      value.fn = this.fn;
      if (this.attribute) {
        value.attribute = this.attribute;
      }
      return value;
    }

    public toJS(): ExpressionJS {
      var js = super.toJS();
      if (this.fn) {
        js.fn = this.fn;
      }
      if (this.attribute) {
        js.attribute = this.attribute.toJS();
      }
      return js;
    }

    public equals(other: AggregateExpression): boolean {
      return super.equals(other) &&
        this.fn === other.fn &&
        Boolean(this.attribute) === Boolean(other.attribute) &&
        (!this.attribute || this.attribute.equals(other.attribute));
    }

    protected _specialEvery(iter: BooleanExpressionIterator): boolean {
      return this.attribute ? this.attribute.every(iter) : true;
    }

    protected _specialSome(iter: BooleanExpressionIterator): boolean {
      return this.attribute ? this.attribute.some(iter) : false;
    }

    public substitute(substitutionFn: SubstitutionFn, genDiff: number): Expression {
      var sub = substitutionFn(this, genDiff);
      if (sub) return sub;
      var subOperand = this.operand.substitute(substitutionFn, genDiff);
      var subAttribute: Expression = null;
      if (this.attribute) {
        subAttribute = this.attribute.substitute(substitutionFn, genDiff + 1);
      }
      if (this.operand === subOperand && this.attribute === subAttribute) return this;

      var value = this.valueOf();
      value.operand = subOperand;
      value.attribute = subAttribute;
      delete value.simple;
      return new AggregateExpression(value);
    }

    public toString(): string {
      return this.operand.toString() + '.' + this.fn + '(' + (this.attribute ? this.attribute.toString() : '') + ')';
    }

    public getComplexity(): number {
      return 1 + this.operand.getComplexity() + (this.attribute ? this.attribute.getComplexity() : 0);
    }

    public simplify(): Expression {
      if (this.simple) return this;
      var simpleOperand = this.operand.simplify();

      if (simpleOperand.isOp('literal')) { // ToDo: also make sure that attribute does not have ^s
        return new LiteralExpression({
          op: 'literal',
          value: this._makeFn(simpleOperand.getFn())()
        })
      }

      var simpleValue = this.valueOf();
      simpleValue.operand = simpleOperand;
      if (this.attribute) {
        simpleValue.attribute = this.attribute.simplify();
      }
      simpleValue.simple = true;
      return new AggregateExpression(simpleValue)
    }

    public containsDataset(): boolean {
      return true;
    }

    protected _makeFn(operandFn: Function): Function {
      var fn = this.fn;
      var attribute = this.attribute;
      var attributeFn = attribute ? attribute.getFn() : null;
      return (d: Datum) => operandFn(d)[fn](attributeFn, attribute);
    }

    protected _makeFnJS(operandFnJS: string): string {
      throw new Error("implement me");
    }

    public _fillRefSubstitutions(typeContext: any, alterations: Alteration[]): any {
      var datasetContext = this.operand._fillRefSubstitutions(typeContext, alterations);
      var attributeType = 'NUMBER';
      if (this.attribute) {
        attributeType = this.attribute._fillRefSubstitutions(datasetContext, alterations);
      }
      return this.fn === 'group' ? ('SET/' + attributeType) : this.type;
    }
  }

  Expression.register(AggregateExpression);
}
