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
        value: this._getFnHelper(literalOperands.map((operand) => operand.getFn()))(null)
      });

      if (nonLiteralOperands.length) {
        if (literalOperands.length) nonLiteralOperands.push(literalExpression);

        var simpleValue = this.valueOf();
        simpleValue.operands = nonLiteralOperands;
        simpleValue.simple = true;
        return new (Expression.classMap[this.op])(simpleValue);
      } else {
        return literalExpression
      }
    }

    public getReferences(): string[] {
      return dedupSort(Array.prototype.concat.apply([], this.operands.map((operand) => operand.getReferences())));
    }

    public getOperandOfType(type: string): Expression[] {
      return this.operands.filter((operand) => operand.isOp(type));
    }

    public every(iter: BooleanExpressionIterator): boolean {
      var pass = iter(this);
      if (pass != null) return false;
      return this.operands.every((operand) => operand.every(iter));
    }

    public forEach(iter: VoidExpressionIterator): void {
      iter(this);
      this.operands.forEach((operand) => operand.forEach(iter));
    }

    public _substituteHelper(substitutionFn: SubstitutionFn, depth: number, genDiff: number): Expression {
      var sub = substitutionFn(this, depth, genDiff);
      if (sub) return sub;
      var subOperands = this.operands.map((operand) => operand._substituteHelper(substitutionFn, depth + 1, genDiff));
      if (this.operands.every((op, i) => op === subOperands[i])) return this;

      var value = this.valueOf();
      value.operands = subOperands;
      delete value.simple;
      return new (Expression.classMap[this.op])(value);
    }

    protected _getFnHelper(operandFns: ComputeFn[]): ComputeFn {
      throw new Error("should never be called directly");
    }

    public getFn(): ComputeFn {
      return this._getFnHelper(this.operands.map((operand) => operand.getFn()));
    }

    protected _getJSExpressionHelper(operandJSExpressions: string[]): string {
      throw new Error("should never be called directly");
    }

    public getJSExpression(): string {
      return this._getJSExpressionHelper(this.operands.map((operand) => operand.getJSExpression()));
    }

    protected _getSQLHelper(operandSQLs: string[], dialect: SQLDialect, minimal: boolean): string {
      throw new Error('should never be called directly');
    }

    public getSQL(dialect: SQLDialect, minimal: boolean = false): string {
      return this._getSQLHelper(this.operands.map((operand) => operand.getSQL(dialect, minimal)), dialect, minimal);
    }

    protected _checkTypeOfOperands(wantedType: string): void {
      var operands = this.operands;
      for (var i = 0; i < operands.length; i++) {
        if (!operands[i].canHaveType(wantedType)) {
          throw new TypeError(this.op + ' must have an operand of type ' + wantedType + ' at position ' + i);
        }
      }
    }

    public _fillRefSubstitutions(typeContext: FullType, alterations: Alteration[]): FullType {
      var remotes = this.operands.map((operand) => operand._fillRefSubstitutions(typeContext, alterations).remote);
      return {
        type: this.type,
        remote: mergeRemotes(remotes)
      };
    }
  }
}
