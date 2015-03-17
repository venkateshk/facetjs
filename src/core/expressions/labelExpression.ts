module Core {
  export class LabelExpression extends UnaryExpression {
    static fromJS(parameters: ExpressionJS): LabelExpression {
      var value = UnaryExpression.jsToValue(parameters);
      value.name = parameters.name;
      return new LabelExpression(value);
    }

    public name: string;

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this.name = parameters.name;
      this._ensureOp("label");
      this._checkTypeOfOperand('SET');
      if (!this.name) throw new Error('split must have a name');
      this.type = 'DATASET';
    }

    public valueOf(): ExpressionValue {
      var value = super.valueOf();
      value.name = this.name;
      return value;
    }

    public toJS(): ExpressionJS {
      var js = super.toJS();
      js.name = this.name;
      return js;
    }

    public toString(): string {
      return this.operand.toString() + ".label('" + this.name + "')";
    }

    public equals(other: LabelExpression): boolean {
      return super.equals(other) &&
        this.name === other.name;
    }

    protected _makeFn(operandFn: Function): Function {
      var name = this.name;
      return (d: Datum) => {
        var mySet = operandFn(d);
        if (!mySet) return null;
        return mySet.label(name);
      }
    }

    protected _makeFnJS(operandFnJS: string): string {
      throw new Error("implement me");
    }

    protected _specialSimplify(simpleOperand: Expression): Expression {
      if (simpleOperand instanceof AggregateExpression && simpleOperand.fn === 'group') {
        var remoteDatasetLiteral = simpleOperand.operand;
        if (remoteDatasetLiteral instanceof LiteralExpression && remoteDatasetLiteral.isRemote()) {
          var remoteDataset: RemoteDataset = remoteDatasetLiteral.value;

          var newRemoteDataset = remoteDataset.addSplit(simpleOperand.attribute, this.name);
          if (!newRemoteDataset) return null;
          return new LiteralExpression({
            op: 'literal',
            value: newRemoteDataset
          })
        }
      }
      return null;
    }

    public _fillRefSubstitutions(typeContext: any, alterations: Alteration[]): any {
      var setType = this.operand._fillRefSubstitutions(typeContext, alterations);
      var newContext: any = { $parent: typeContext };
      // setType will be something like SET/STRING we need to chop off the SET/
      newContext[this.name] = setType.substring(4);

      return newContext;
    }

    public simulateResolved(): any {
      return this.operand.simulateResolved().label(this.name);
    }
  }

  Expression.register(LabelExpression);
}
