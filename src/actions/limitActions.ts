module Actions {

  export class LimitAction extends Action {
    static fromJS(parameters: ActionJS): LimitAction {
      return new LimitAction({
        action: parameters.action,
        limit: parameters.limit
      });
    }

    public limit: number;

    constructor(parameters: ActionValue = {}) {
      super(parameters, dummyObject);
      this.limit = parameters.limit;
      this._ensureAction("limit");
    }

    public valueOf(): ActionValue {
      var value = super.valueOf();
      value.limit = this.limit;
      return value;
    }

    public toJS(): ActionJS {
      var js = super.toJS();
      js.limit = this.limit;
      return js;
    }

    public toString(): string {
      return 'Limit(' + this.limit + ')';
    }

    public equals(other: LimitAction): boolean {
      return super.equals(other) &&
        this.limit === other.limit;
    }
  }

  Action.register(LimitAction);

}
