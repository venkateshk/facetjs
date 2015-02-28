module Core {
  export class DefAction extends Action {
    static fromJS(parameters: ActionJS): DefAction {
      return new DefAction({
        action: parameters.action,
        name: parameters.name,
        expression: Expression.fromJS(parameters.expression)
      });
    }

    public name: string;

    constructor(parameters: ActionValue = {}) {
      super(parameters, dummyObject);
      this.name = parameters.name;
      this._ensureAction("def");
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
      return '.def(' + this.name + ', ' + this.expression.toString() + ')';
    }

    public equals(other: DefAction): boolean {
      return super.equals(other) &&
        this.name === other.name;
    }
  }

  Action.register(DefAction);
}
