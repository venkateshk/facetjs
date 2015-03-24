module Core {
  var fnToSQL: Lookup<string> = {
    count: 'COUNT(',
    sum: 'SUM(',
    average: 'AVG(',
    min: 'MIN(',
    max: 'MAX(',
    uniqueCount: 'COUNT(DISTINCT '
  };

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

    public toString(): string {
      return this.operand.toString() + '.' + this.fn + '(' + (this.attribute ? this.attribute.toString() : '') + ')';
    }

    public equals(other: AggregateExpression): boolean {
      return super.equals(other) &&
        this.fn === other.fn &&
        Boolean(this.attribute) === Boolean(other.attribute) &&
        (!this.attribute || this.attribute.equals(other.attribute));
    }

    protected _getFnHelper(operandFn: ComputeFn): ComputeFn {
      var fn = this.fn;
      var attribute = this.attribute;
      var attributeFn = attribute ? attribute.getFn() : null;
      return (d: Datum) => operandFn(d)[fn](attributeFn, attribute);
    }

    protected _getJSExpressionHelper(operandFnJS: string): string {
      throw new Error("implement me");
    }

    protected _getSQLHelper(operandSQL: string, dialect: SQLDialect, minimal: boolean): string {
      var operand = this.operand;
      if (operand instanceof RefExpression) {
        var attributeSQL = this.attribute ? this.attribute.getSQL(dialect, minimal) : '1';
        return fnToSQL[this.fn] + attributeSQL + ')';
      }
      throw new Error("can not getSQL with complex operand");
    }

    protected _specialEvery(iter: BooleanExpressionIterator): boolean {
      return this.attribute ? this.attribute.every(iter) : true;
    }

    protected _specialForEach(iter: VoidExpressionIterator): void {
      if (this.attribute) this.attribute.forEach(iter);
    }

    public _substituteHelper(substitutionFn: SubstitutionFn, depth: number, genDiff: number): Expression {
      var sub = substitutionFn(this, depth, genDiff);
      if (sub) return sub;
      var subOperand = this.operand._substituteHelper(substitutionFn, depth + 1, genDiff);
      var subAttribute: Expression = null;
      if (this.attribute) {
        subAttribute = this.attribute._substituteHelper(substitutionFn, depth + 1, genDiff + 1);
      }
      if (this.operand === subOperand && this.attribute === subAttribute) return this;

      var value = this.valueOf();
      value.operand = subOperand;
      value.attribute = subAttribute;
      delete value.simple;
      return new AggregateExpression(value);
    }

    public getComplexity(): number {
      return 1 + this.operand.getComplexity() + (this.attribute ? this.attribute.getComplexity() : 0);
    }

    public simplify(): Expression {
      if (this.simple) return this;
      var simpleOperand = this.operand.simplify();

      if (simpleOperand instanceof LiteralExpression && !simpleOperand.isRemote()) { // ToDo: also make sure that attribute does not have ^s
        return new LiteralExpression({
          op: 'literal',
          value: this._getFnHelper(simpleOperand.getFn())(null)
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

    public _fillRefSubstitutions(typeContext: FullType, alterations: Alteration[]): FullType {
      var datasetContext = this.operand._fillRefSubstitutions(typeContext, alterations);
      var attributeType = 'NUMBER';
      if (this.attribute) {
        attributeType = this.attribute._fillRefSubstitutions(datasetContext, alterations).type;
      }
      return {
        type: this.fn === 'group' ? ('SET/' + attributeType) : this.type,
        remote: datasetContext.remote
      };
    }
  }

  Expression.register(AggregateExpression);
}
