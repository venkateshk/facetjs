module Core {
  export class UnaryExpression extends Expression {
    static jsToValue(parameters: ExpressionJS): ExpressionValue {
      var value: ExpressionValue = {
        op: parameters.op
      };
      if (parameters.operand) {
        value.operand = Expression.fromJSLoose(parameters.operand);
      } else {
        throw new TypeError("must have a operand");
      }

      return value;
    }

    public operand: Expression;

    constructor(parameters: ExpressionValue, dummyObject: Dummy) {
      super(parameters, dummyObject);
      this.operand = parameters.operand;
    }

    public valueOf(): ExpressionValue {
      var value = super.valueOf();
      value.operand = this.operand;
      return value;
    }

    public toJS(): ExpressionJS {
      var js: ExpressionJS = super.toJS();
      js.operand = this.operand.toJS();
      return js;
    }

    public equals(other: UnaryExpression): boolean {
      return super.equals(other) &&
        this.operand.equals(other.operand)
    }

    public getComplexity(): number {
      return 1 + this.operand.getComplexity()
    }

    protected _specialSimplify(simpleOperand: Expression): Expression {
      return null;
    }

    public simplify(): Expression {
      if (this.simple) return this;
      var simpleOperand = this.operand.simplify();

      var special = this._specialSimplify(simpleOperand);
      if (special) return special;

      if (simpleOperand.isOp('literal')) {
        return new LiteralExpression({
          op: 'literal',
          value: this._getFnHelper(simpleOperand.getFn())(null)
        })
      }

      var simpleValue = this.valueOf();
      simpleValue.operand = simpleOperand;
      simpleValue.simple = true;
      return new (Expression.classMap[this.op])(simpleValue);
    }

    public containsDataset(): boolean {
      return this.operand.containsDataset();
    }

    public getReferences(): string[] {
      return this.operand.getReferences();
    }

    public getOperandOfType(type: string): Expression[] {
      if (this.operand.isOp(type)) {
        return [this.operand];
      } else {
        return []
      }
    }

    protected _specialEvery(iter: BooleanExpressionIterator): boolean {
      return true;
    }

    public every(iter: BooleanExpressionIterator): boolean {
      var pass = iter(this);
      if (pass != null) return pass;
      return this.operand.every(iter) && this._specialEvery(iter);
    }

    protected _specialForEach(iter: VoidExpressionIterator): void {
    }

    public forEach(iter: VoidExpressionIterator): void {
      iter(this);
      this.operand.forEach(iter);
      this._specialForEach(iter);
    }

    public _substituteHelper(substitutionFn: SubstitutionFn, depth: number, genDiff: number): Expression {
      var sub = substitutionFn(this, depth, genDiff);
      if (sub) return sub;
      var subOperand = this.operand._substituteHelper(substitutionFn, depth + 1, genDiff);
      if (this.operand === subOperand) return this;

      var value = this.valueOf();
      value.operand = subOperand;
      delete value.simple;
      return new (Expression.classMap[this.op])(value);
    }

    protected _getFnHelper(operandFn: ComputeFn): ComputeFn {
      throw new Error("should never be called directly");
    }

    public getFn(): ComputeFn {
      return this._getFnHelper(this.operand.getFn());
    }

    protected _getJSExpressionHelper(operandFnJS: string): string {
      throw new Error("should never be called directly");
    }

    public getJSExpression(): string {
      return this._getJSExpressionHelper(this.operand.getJSExpression());
    }

    protected _getSQLHelper(operandSQL: string): string {
      throw new Error('should never be called directly');
    }

    public getSQL(): string {
      return this._getSQLHelper(this.operand.getSQL());
    }

    protected _checkTypeOfOperand(wantedType: string): void {
      if (!this.operand.canHaveType(wantedType)) {
        throw new TypeError(this.op + ' expression must have an operand of type ' + wantedType);
      }
    }

    public _fillRefSubstitutions(typeContext: FullType, alterations: Alteration[]): FullType {
      var operandFullType = this.operand._fillRefSubstitutions(typeContext, alterations);
      return {
        type: this.type,
        remote: operandFullType.remote
      };
    }
  }
}
