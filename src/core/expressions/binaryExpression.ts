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

    protected simple: boolean;

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
      var simpleLhs = this.lhs.simplify();
      var simpleRhs = this.rhs.simplify();

      var special = this._specialSimplify(simpleLhs, simpleRhs);
      if (special) return special;

      if (simpleLhs.isOp('literal') && simpleRhs.isOp('literal')) {
        return new LiteralExpression({
          op: 'literal',
          value: this._makeFn(simpleLhs.getFn(), simpleRhs.getFn())()
        })
      }

      var value = this.valueOf();
      value.lhs = simpleLhs;
      value.rhs = simpleRhs;
      return new (Expression.classMap[this.op])(value);
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
      return this.lhs.getReferences().concat(this.rhs.getReferences()).sort();
    }

    public substitute(substitutionFn: SubstitutionFn, genDiff: number): Expression {
      var sub = substitutionFn(this, genDiff);
      if (sub) return sub;
      var subLhs = this.lhs.substitute(substitutionFn, genDiff);
      var subRhs = this.rhs.substitute(substitutionFn, genDiff);
      if (this.lhs === subLhs && this.rhs === subRhs) return this;
      var value = this.valueOf();
      value.lhs = subLhs;
      value.rhs = subRhs;
      return new (Expression.classMap[this.op])(value);
    }

    protected _makeFn(lhsFn: Function, rhsFn: Function): Function {
      throw new Error("should never be called directly");
    }

    public getFn(): Function {
      return this._makeFn(this.lhs.getFn(), this.rhs.getFn());
    }

    protected _makeFnJS(lhsFnJS: string, rhsFnJS: string): string {
      throw new Error("should never be called directly");
    }

    /* protected */
    public _getRawFnJS(): string {
      return this._makeFnJS(this.lhs._getRawFnJS(), this.rhs._getRawFnJS())
    }

    protected _checkTypeOf(lhsRhs: string, wantedType: string): void {
      var operand: Expression = (<any>this)[lhsRhs];
      if (!operand.canHaveType(wantedType)) {
        throw new TypeError(this.op + ' ' + lhsRhs + ' must be of type ' + wantedType);
      }
    }

    public _fillRefSubstitutions(typeContext: any, alterations: Alteration[]): any {
      this.lhs._fillRefSubstitutions(typeContext, alterations);
      this.rhs._fillRefSubstitutions(typeContext, alterations);
      return this.type;
    }
  }
}
