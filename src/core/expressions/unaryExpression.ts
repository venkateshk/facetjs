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
      var simpleOperand = this.operand.simplify();

      var special = this._specialSimplify(simpleOperand);
      if (special) return special;

      if (simpleOperand.isOp('literal')) {
        return new LiteralExpression({
          op: 'literal',
          value: this._makeFn(simpleOperand.getFn())()
        })
      }

      var value = this.valueOf();
      value.operand = simpleOperand;
      return new (Expression.classMap[this.op])(value);
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

    public substitute(substitutionFn: SubstitutionFn, genDiff: number): Expression {
      var sub = substitutionFn(this, genDiff);
      if (sub) return sub;
      var subOperand = this.operand.substitute(substitutionFn, genDiff);
      if (this.operand === subOperand) return this;
      var value = this.valueOf();
      value.operand = subOperand;
      return new (Expression.classMap[this.op])(value);
    }

    protected _makeFn(operandFn: Function): Function {
      throw new Error("should never be called directly");
    }

    public getFn(): Function {
      return this._makeFn(this.operand.getFn());
    }

    protected _makeFnJS(operandFnJS: string): string {
      throw new Error("should never be called directly");
    }

    /* protected */
    public _getRawFnJS(): string {
      return this._makeFnJS(this.operand._getRawFnJS())
    }

    protected _checkTypeOfOperand(wantedType: string): void {
      if (!this.operand.canHaveType(wantedType)) {
        throw new TypeError(this.op + ' expression must have an operand of type ' + wantedType);
      }
    }

    public _fillRefSubstitutions(typeContext: any, alterations: Alteration[]): any {
      this.operand._fillRefSubstitutions(typeContext, alterations);
      return this.type;
    }
  }
}
