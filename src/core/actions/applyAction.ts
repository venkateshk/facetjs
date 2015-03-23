module Core {
  export class ApplyAction extends Action {
    static fromJS(parameters: ActionJS): ApplyAction {
      return new ApplyAction({
        action: parameters.action,
        name: parameters.name,
        expression: Expression.fromJS(parameters.expression)
      });
    }

    public name: string;

    constructor(parameters: ActionValue = {}) {
      super(parameters, dummyObject);
      this.name = parameters.name;
      this._ensureAction("apply");
    }

    public valueOf(): ActionValue {
      var value = super.valueOf();
      value.name = this.name;
      return value;
    }

    public toJS(): ActionJS {
      var js = super.toJS();
      js.name = this.name;
      return js;
    }

    public toString(): string {
      return `.apply(${this.name}, ${this.expression.toString()})`;
    }

    public equals(other: ApplyAction): boolean {
      return super.equals(other) &&
        this.name === other.name;
    }

    public getSQL(): string {
      return `${this.expression.getSQL()} AS '${this.name}'`;
    }
  }
  Action.register(ApplyAction);
}
