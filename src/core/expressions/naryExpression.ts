module Core {
  export class NaryExpression extends Expression {
    static jsToValue(parameters: ExpressionJS): ExpressionValue {
      var op = parameters.op;
      var value: ExpressionValue = {
        op: op
      };
      if (Array.isArray(parameters.operands)) {
        value.operands = parameters.operands.map((operand) => Expression.fromJSLoose(operand));
      } else {
        throw new TypeError("must have a operands");
      }

      return value;
    }

    public operands: Expression[];

    constructor(parameters: ExpressionValue, dummyObject: Dummy) {
      super(parameters, dummyObject);
      this.operands = parameters.operands;
    }

    public valueOf(): ExpressionValue {
      var value = super.valueOf();
      value.operands = this.operands;
      return value;
    }

    public toJS(): ExpressionJS {
      var js = super.toJS();
      js.operands = this.operands.map((operand) => operand.toJS());
      return js;
    }

    public equals(other: NaryExpression): boolean {
      if (!(super.equals(other) && this.operands.length === other.operands.length)) return false;
      var thisOperands = this.operands;
      var otherOperands = other.operands;
      for (var i = 0; i < thisOperands.length; i++) {
        if (!thisOperands[i].equals(otherOperands[i])) return false;
      }
      return true;
    }

    public getComplexity(): number {
      var complexity = 1;
      var operands = this.operands;
      for (var i = 0; i < operands.length; i++) {
        complexity += operands[i].getComplexity();
      }
      return complexity;
    }

    protected _specialSimplify(simpleOperands: Expression[]): Expression {
      return null;
    }

    public simplify(): Expression {
      if (this.simple) return this;
      var simpleOperands: Expression[] = this.operands.map((operand) => operand.simplify());

      var special = this._specialSimplify(simpleOperands);
      if (special) return special;

      var literalOperands = simpleOperands.filter((operand) => operand.isOp('literal'));
      var nonLiteralOperands = simpleOperands.filter((operand) => !operand.isOp('literal'));
      var literalExpression = new LiteralExpression({
        op: 'literal',
        value: this._makeFn(literalOperands.map((operand) => operand.getFn()))()
      });

      if (nonLiteralOperands.length) {
        nonLiteralOperands.push(literalExpression);
        var simpleValue = this.valueOf();
        simpleValue.operands = nonLiteralOperands;
        simpleValue.simple = true;
        return new (Expression.classMap[this.op])(simpleValue);
      } else {
        return literalExpression
      }
    }

    public containsDataset(): boolean {
      return this.operands.some((operand) => operand.containsDataset());
    }

    public getReferences(): string[] {
      return dedupSort(Array.prototype.concat.apply([], this.operands.map((operand) => operand.getReferences())));
    }

    public getOperandOfType(type: string): Expression[] {
      return this.operands.filter((operand) => operand.isOp(type));
    }

    public every(iter: BooleanExpressionIterator): boolean {
      var pass = iter(this);
      if (!pass) return false;
      return this.operands.every((operand) => operand.every(iter));
    }

    public some(iter: BooleanExpressionIterator): boolean {
      var pass = iter(this);
      if (pass) return true;
      return this.operands.some((operand) => operand.some(iter));
    }

    public substitute(substitutionFn: SubstitutionFn, genDiff: number): Expression {
      var sub = substitutionFn(this, genDiff);
      if (sub) return sub;
      var subOperands = this.operands.map((operand) => operand.substitute(substitutionFn, genDiff));
      if (this.operands.every((op, i) => op === subOperands[i])) return this;

      var value = this.valueOf();
      value.operands = subOperands;
      delete value.simple;
      return new (Expression.classMap[this.op])(value);
    }

    protected _makeFn(operandFns: Function[]): Function {
      throw new Error("should never be called directly");
    }

    public getFn(): Function {
      return this._makeFn(this.operands.map((operand) => operand.getFn()));
    }

    protected _makeFnJS(operandFnJSs: string[]): string {
      throw new Error("should never be called directly");
    }

    /* protected */
    public _getRawFnJS(): string {
      return this._makeFnJS(this.operands.map((operand) => operand._getRawFnJS()));
    }

    protected _checkTypeOfOperands(wantedType: string): void {
      var operands = this.operands;
      for (var i = 0; i < operands.length; i++) {
        if (!operands[i].canHaveType(wantedType)) {
          throw new TypeError(this.op + ' must have an operand of type ' + wantedType + ' at position ' + i);
        }
      }
    }

    public _fillRefSubstitutions(typeContext: any, alterations: Alteration[]): any {
      var operands = this.operands;
      for (var i = 0; i < operands.length; i++) {
        operands[i]._fillRefSubstitutions(typeContext, alterations);
      }
      return this.type;
    }
  }
}
