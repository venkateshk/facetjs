module Core {
  export class BinaryExpression extends Expression {
    static jsToValue(parameters: ExpressionJS): ExpressionValue {
      var op = parameters.op;
      var value: ExpressionValue = {
        op: op
      };
      if (typeof parameters.lhs !== 'undefined' && parameters.lhs !== null) {
        value.lhs = Expression.fromJSLoose(parameters.lhs);
      } else {
        throw new TypeError("must have a lhs");
      }

      if (typeof parameters.rhs !== 'undefined' && parameters.rhs !== null) {
        value.rhs = Expression.fromJSLoose(parameters.rhs);
      } else {
        throw new TypeError("must have a rhs");
      }

      return value;
    }

    public lhs: Expression;
    public rhs: Expression;

    constructor(parameters: ExpressionValue, dummyObject: Dummy) {
      super(parameters, dummyObject);
      this.lhs = parameters.lhs;
      this.rhs = parameters.rhs;
    }

    public valueOf(): ExpressionValue {
      var value = super.valueOf();
      value.lhs = this.lhs;
      value.rhs = this.rhs;
      return value;
    }

    public toJS(): ExpressionJS {
      var js = super.toJS();
      js.lhs = this.lhs.toJS();
      js.rhs = this.rhs.toJS();
      return js;
    }

    public equals(other: BinaryExpression): boolean {
      return super.equals(other) &&
        this.lhs.equals(other.lhs) &&
        this.rhs.equals(other.rhs);
    }

    public getComplexity(): number {
      return 1 + this.lhs.getComplexity() + this.rhs.getComplexity()
    }

    protected _specialSimplify(simpleLhs: Expression, simpleRhs: Expression): Expression {
      return null;
    }

    public simplify(): Expression {
      if (this.simple) return this;
      var simpleLhs = this.lhs.simplify();
      var simpleRhs = this.rhs.simplify();

      var special = this._specialSimplify(simpleLhs, simpleRhs);
      if (special) return special;

      if (simpleLhs.isOp('literal') && simpleRhs.isOp('literal')) {
        return new LiteralExpression({
          op: 'literal',
          value: this._getFnHelper(simpleLhs.getFn(), simpleRhs.getFn())(null)
        })
      }

      var simpleValue = this.valueOf();
      simpleValue.lhs = simpleLhs;
      simpleValue.rhs = simpleRhs;
      simpleValue.simple = true;
      return new (Expression.classMap[this.op])(simpleValue);
    }

    public containsDataset(): boolean {
      return this.lhs.containsDataset() || this.rhs.containsDataset();
    }

    public getOperandOfType(type: string): Expression[] {
      var ret: Expression[] = [];

      if (this.lhs.isOp(type)) ret.push(this.lhs);
      if (this.rhs.isOp(type)) ret.push(this.rhs);
      return ret;
    }

    public checkLefthandedness(): boolean {
      if (this.lhs instanceof RefExpression && this.rhs instanceof RefExpression) return null;
      if (this.lhs instanceof RefExpression) return true;
      if (this.rhs instanceof RefExpression) return false;

      return null;
    }

    public getReferences(): string[] {
      return dedupSort(this.lhs.getReferences().concat(this.rhs.getReferences()));
    }

    public every(iter: BooleanExpressionIterator): boolean {
      var pass = iter(this);
      if (pass != null) return pass;
      return this.lhs.every(iter) && this.rhs.every(iter);
    }

    public forEach(iter: VoidExpressionIterator): void {
      iter(this);
      this.lhs.forEach(iter);
      this.rhs.forEach(iter);
    }

    public _substituteHelper(substitutionFn: SubstitutionFn, depth: number, genDiff: number): Expression {
      var sub = substitutionFn(this, depth, genDiff);
      if (sub) return sub;
      var subLhs = this.lhs._substituteHelper(substitutionFn, depth, genDiff);
      var subRhs = this.rhs._substituteHelper(substitutionFn, depth, genDiff);
      if (this.lhs === subLhs && this.rhs === subRhs) return this;

      var value = this.valueOf();
      value.lhs = subLhs;
      value.rhs = subRhs;
      delete value.simple;
      return new (Expression.classMap[this.op])(value);
    }

    protected _getFnHelper(lhsFn: ComputeFn, rhsFn: ComputeFn): ComputeFn {
      throw new Error("should never be called directly");
    }

    public getFn(): ComputeFn {
      return this._getFnHelper(this.lhs.getFn(), this.rhs.getFn());
    }

    protected _getJSExpressionHelper(lhsFnJS: string, rhsFnJS: string): string {
      throw new Error("should never be called directly");
    }

    public getJSExpression(): string {
      return this._getJSExpressionHelper(this.lhs.getJSExpression(), this.rhs.getJSExpression())
    }

    protected _getSQLHelper(lhsSQL: string, rhsSQL: string): string {
      throw new Error('should never be called directly');
    }

    public getSQL(): string {
      return this._getSQLHelper(this.lhs.getSQL(), this.rhs.getSQL());
    }

    protected _checkTypeOf(lhsRhs: string, wantedType: string): void {
      var operand: Expression = (<any>this)[lhsRhs];
      if (!operand.canHaveType(wantedType)) {
        throw new TypeError(this.op + ' ' + lhsRhs + ' must be of type ' + wantedType);
      }
    }

    public _fillRefSubstitutions(typeContext: FullType, alterations: Alteration[]): FullType {
      var lhsFullType = this.lhs._fillRefSubstitutions(typeContext, alterations);
      var rhsFullType = this.rhs._fillRefSubstitutions(typeContext, alterations);
      return {
        type: this.type,
        remote: mergeRemotes([lhsFullType.remote, rhsFullType.remote])
      };
    }
  }
}
