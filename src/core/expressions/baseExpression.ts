module Core {
  export interface SubstitutionFn {
    (ex: Expression, genDiff: number): Expression;
  }

  export interface ExpressionValue {
    op: string;
    type?: string;
    value?: any;
    name?: string;
    lhs?: Expression;
    rhs?: Expression;
    operand?: Expression;
    operands?: Expression[];
    actions?: Action[];
    regexp?: string;
    fn?: string;
    attribute?: Expression;
    offset?: number;
    size?: number;
    duration?: Duration;
    timezone?: Timezone;
  }

  export interface ExpressionJS {
    op: string;
    type?: string;
    value?: any;
    name?: string;
    lhs?: ExpressionJS;
    rhs?: ExpressionJS;
    operand?: ExpressionJS;
    operands?: ExpressionJS[];
    actions?: ActionJS[];
    regexp?: string;
    fn?: string;
    attribute?: ExpressionJS;
    offset?: number;
    size?: number;
    duration?: string;
    timezone?: string;
  }

  export interface Alteration {
    from: Expression;
    to: Expression;
  }

  export var possibleTypes = ['NULL', 'BOOLEAN', 'NUMBER', 'TIME', 'STRING', 'NUMBER_RANGE', 'TIME_RANGE', 'SET', 'DATASET'];

  export var checkArrayEquality = function(a: Array<any>, b: Array<any>) {
    return a.every((item, i) =>  (item === b[i]));
  };

  /**
   * The expression starter function. Performs different operations depending on the type and value of the input
   * facet() produces a native dataset with a singleton empty datum inside of it. This is useful to describe the base container
   * facet('blah') produces an reference lookup expression on 'blah'
   * facet(driver) produces a remote dataset accessible via the driver
   *
   * @param input The input that can be nothing, a string, or a driver
   * @returns {Expression}
   */
  export function facet(input: any = null): Expression {
    if (input) {
      if (typeof input === 'string') {
        var parts = input.split(':');
        var refValue: ExpressionValue = {
          op: 'ref',
          name: parts[0]
        };
        if (parts.length > 1) refValue.type = parts[1];
        return new RefExpression(refValue);
      } else {
        return new LiteralExpression({ op: 'literal', value: input });
      }
    } else {
      return new LiteralExpression({
        op: 'literal',
        value: new NativeDataset({ source: 'native', data: [{}] })
      });
    }
  }

  var check: ImmutableClass<ExpressionValue, ExpressionJS>;

  /**
   * Provides a way to express arithmetic operations, aggregations and database operators.
   * This class is the backbone of facet.js
   */
  export class Expression implements ImmutableInstance<ExpressionValue, ExpressionJS> {
    static FALSE: LiteralExpression;
    static TRUE: LiteralExpression;
    static isExpression(candidate: any): boolean {
      return isInstanceOf(candidate, Expression);
    }

    /**
     * Parses an expression
     *
     * @param str The expression to parse
     * @returns {Expression}
     */
    static parse(str: string): Expression {
      return Expression.fromJS(expressionParser.parse(str));
    }

    /**
     * Deserializes or parses an expression
     *
     * @param param The expression to parse
     * @returns {Expression}
     */
    static fromJSLoose(param: any): Expression {
      var expressionJS: ExpressionJS;
      // Quick parse simple expressions
      switch (typeof param) {
        case 'object':
          if (Expression.isExpression(param)) {
            return param
          } else if (isHigherObject(param)) {
            if (param.constructor.type) {
              // Must be a datatype
              expressionJS = { op: 'literal', value: param };
            } else {
              throw new Error("unknown object"); //ToDo: better error
            }
          } else if (param.op) {
            expressionJS = <ExpressionJS>param;
          } else if (Array.isArray(param)) {
            expressionJS = { op: 'literal', value: Set.fromJS(param) };
          } else if (param.hasOwnProperty('start') && param.hasOwnProperty('end')) {
            if (typeof param.start === 'number') {
              expressionJS = { op: 'literal', value: NumberRange.fromJS(param) };
            } else {
              expressionJS = { op: 'literal', value: TimeRange.fromJS(param) };
            }
          } else {
            throw new Error('unknown parameter');
          }
          break;

        case 'number':
          expressionJS = { op: 'literal', value: param };
          break;

        case 'string':
          if (/^\w+$/.test(param)) {
            expressionJS = { op: 'literal', value: param };
          } else {
            expressionJS = expressionParser.parse(param);
          }
          break;

        default:
          throw new Error("unrecognizable expression");
      }

      return Expression.fromJS(expressionJS);
    }

    static classMap: Lookup<typeof Expression> = {};
    static register(ex: typeof Expression): void {
      var op = (<any>ex).name.replace('Expression', '').replace(/^\w/, (s: string) => s.toLowerCase());
      Expression.classMap[op] = ex;
    }

    /**
     * Deserializes the expression JSON
     *
     * @param expressionJS
     * @returns {any}
     */
    static fromJS(expressionJS: ExpressionJS): Expression {
      if (!expressionJS.hasOwnProperty("op")) {
        throw new Error("op must be defined");
      }
      var op = expressionJS.op;
      if (typeof op !== "string") {
        throw new Error("op must be a string");
      }
      var ClassFn = Expression.classMap[op];
      if (!ClassFn) {
        throw new Error("unsupported expression op '" + op + "'");
      }

      return ClassFn.fromJS(expressionJS);
    }

    public op: string;
    public type: string;

    constructor(parameters: ExpressionValue, dummy: Dummy = null) {
      this.op = parameters.op;
      if (dummy !== dummyObject) {
        throw new TypeError("can not call `new Expression` directly use Expression.fromJS instead");
      }
    }

    protected _ensureOp(op: string) {
      if (!this.op) {
        this.op = op;
        return;
      }
      if (this.op !== op) {
        throw new TypeError("incorrect expression op '" + this.op + "' (needs to be: '" + op + "')");
      }
    }

    public valueOf(): ExpressionValue {
      return {
        op: this.op
      };
    }

    /**
     * Serializes the expression into a simple JS object that can be passed to JSON.serialize
     *
     * @returns ExpressionJS
     */
    public toJS(): ExpressionJS {
      return {
        op: this.op
      };
    }

    /**
     * Makes it safe to call JSON.serialize on expressions
     *
     * @returns ExpressionJS
     */
    public toJSON(): ExpressionJS {
      return this.toJS();
    }

    /**
     * Validate that two expressions are equal in their meaning
     *
     * @param other
     * @returns {boolean}
     */
    public equals(other: Expression): boolean {
      return Expression.isExpression(other) &&
        this.op === other.op &&
        this.type === other.type;
    }

    /**
     * Check that the expression can potentially have the desired type
     * If wanted type is 'SET' then any SET/* type is matched
     *
     * @param wantedType The type that is wanted
     * @returns {boolean}
     */
    public canHaveType(wantedType: string): boolean {
      if (!this.type) return true;
      if (wantedType === 'SET') {
        return this.type.indexOf('SET/') === 0;
      } else {
        return this.type === wantedType;
      }
    }

    /**
     * Compute the relative complexity of the expression
     *
     * @returns {number}
     */
    public getComplexity(): number {
      return 1;
    }

    /**
     * Check if the expression has the given operation (op)
     *
     * @param op The operation to test
     * @returns {boolean}
     */
    public isOp(op: string): boolean {
      return this.op === op;
    }

    /**
     * Introspects self to look for all references expressions and returns the alphabetically sorted list of the references
     *
     * @returns {string[]}
     */
    public getReferences(): string[] {
      throw new Error('please implement');
    }

    /**
     * Sifts through operands to find all operands of a certain type
     *
     * @param type{string} Type of operand to look for
     * @returns {Expression[]}
     */
    public getOperandOfType(type: string): Expression[] {
      throw new Error('please implement');
    }

    /**
     * Merge self with the provided expression for AND operation and returns a merged expression.
     *
     * @returns {Expression}
     */
    public mergeAnd(a: Expression): Expression {
      throw new Error('please implement');
    }

    /**
     * Merge self with the provided expression for OR operation and returns a merged expression.
     *
     * @returns {Expression}
     */
    public mergeOr(a: Expression): Expression {
      throw new Error('please implement');
    }

    /**
     * Returns an expression that is equivalent but no more complex
     * If no simplification can be done will return itself.
     *
     * @returns {Expression}
     */
    public simplify(): Expression {
      return this;
    }

    /**
     * Performs a substitution by recursively applying the given substitutionFn to every sub-expression
     * if substitutionFn returns an expression than it is replaced; if null is returned no action is taken.
     *
     * @param substitutionFn
     */
    public substitute(substitutionFn: SubstitutionFn, genDiff: number): Expression {
      var sub = substitutionFn(this, genDiff);
      if (sub) return sub;
      return this;
    }

    public getFn(): Function {
      throw new Error('should never be called directly');
    }

    /* protected */
    public _getRawFnJS(): string {
      throw new Error('should never be called directly');
    }

    public getFnJS(wrap: boolean = true) {
      var rawFnJS = this._getRawFnJS();
      if (wrap) {
        return 'function(d){return ' + rawFnJS + ';}';
      } else {
        return rawFnJS;
      }
    }

    // Action constructors
    protected _performAction(action: Action): Expression {
      return new ActionsExpression({
        op: 'actions',
        operand: this,
        actions: [action]
      });
    }

    /**
     * Evaluate some expression on every datum in the dataset. Record the result as `name`
     *
     * @param name The name of where to store the results
     * @param ex The expression to evaluate
     * @returns {Expression}
     */
    public apply(name: string, ex: any): Expression {
      if (!Expression.isExpression(ex)) ex = Expression.fromJSLoose(ex);
      return this._performAction(new ApplyAction({ name: name, expression: ex }));
    }

    /**
     * Evaluate some expression on every datum in the dataset. Temporarily record the result as `name`
     * Same as `apply` but is better suited for temporary results.
     *
     * @param name The name of where to store the results
     * @param ex The expression to evaluate
     * @returns {Expression}
     */
    public def(name: string, ex: any): Expression {
      if (!Expression.isExpression(ex)) ex = Expression.fromJSLoose(ex);
      return this._performAction(new DefAction({ name: name, expression: ex }));
    }

    /**
     * Filter the dataset with a boolean expression
     * Only works on expressions that return DATASET
     *
     * @param ex A boolean expression to filter on
     * @returns {Expression}
     */
    public filter(ex: any): Expression {
      if (!Expression.isExpression(ex)) ex = Expression.fromJSLoose(ex);
      return this._performAction(new FilterAction({ expression: ex }));
    }

    /**
     *
     * @param ex
     * @param direction
     * @returns {Expression}
     */
    public sort(ex: any, direction: string): Expression {
      if (!Expression.isExpression(ex)) ex = Expression.fromJSLoose(ex);
      return this._performAction(new SortAction({ expression: ex, direction: direction }));
    }

    public limit(limit: number): Expression {
      return this._performAction(new LimitAction({ limit: limit }));
    }

    // Expression constructors (Unary)
    protected _performUnaryExpression(newValue: ExpressionValue): Expression {
      newValue.operand = this;
      return new (Expression.classMap[newValue.op])(newValue);
    }

    public not() { return this._performUnaryExpression({ op: 'not' }); }
    public match(re: string) { return this._performUnaryExpression({ op: 'match', regexp: re }); }

    public negate() { return this._performUnaryExpression({ op: 'negate' }); }
    public reciprocate() { return this._performUnaryExpression({ op: 'reciprocate' }); }

    public numberBucket(size: number, offset: number = 0) {
      return this._performUnaryExpression({ op: 'numberBucket', size: size, offset: offset });
    }

    public timeBucket(duration: any, timezone: any) {
      if (!Duration.isDuration(duration)) duration = Duration.fromJS(duration);
      if (!Timezone.isTimezone(timezone)) timezone = Timezone.fromJS(timezone);
      return this._performUnaryExpression({ op: 'timeBucket', duration: duration, timezone: timezone });
    }

    // Aggregators
    protected _performAggregate(fn: string, attribute: any): Expression {
      if (!Expression.isExpression(attribute)) attribute = Expression.fromJSLoose(attribute);
      return this._performUnaryExpression({
        op: 'aggregate',
        fn: fn,
        attribute: attribute
      });
    }

    public count() { return this._performUnaryExpression({ op: 'aggregate', fn: 'count' }); }
    public sum(attr: any) { return this._performAggregate('sum', attr); }
    public min(attr: any) { return this._performAggregate('min', attr); }
    public max(attr: any) { return this._performAggregate('max', attr); }
    public group(attr: any) { return this._performAggregate('group', attr); }

    // Label
    public label(name: string): Expression {
      return this._performUnaryExpression({
        op: 'label',
        name: name
      });
    }

    // Split // .split(attr, l, d) = .group(attr).label(l).def(d, facet(d).filter(ex = ^l))
    public split(attribute: any, name: string, dataName: string = null): Expression {
      if (!Expression.isExpression(attribute)) attribute = Expression.fromJSLoose(attribute);
      if (!dataName) {
        if (this.isOp('ref')) {
          dataName = (<RefExpression>this).name;
        } else {
          throw new Error("could not guess data name in `split`, please provide one explicitly")
        }
      }
      return this.group(attribute).label(name)
        .def(dataName, facet(dataName).filter(attribute.is(facet('^' + name))));
    }

    // Expression constructors (Binary)
    protected _performBinaryExpression(newValue: ExpressionValue, otherEx: any): Expression {
      if (typeof otherEx === 'undefined') new Error('must have argument');
      if (!Expression.isExpression(otherEx)) otherEx = Expression.fromJSLoose(otherEx);
      newValue.lhs = this;
      newValue.rhs = otherEx;
      return new (Expression.classMap[newValue.op])(newValue);
    }

    public is(ex: any) { return this._performBinaryExpression({ op: 'is' }, ex); }
    public in(ex: any) { return this._performBinaryExpression({ op: 'in' }, ex); }
    public lessThan(ex: any) { return this._performBinaryExpression({ op: 'lessThan' }, ex); }
    public lessThanOrEqual(ex: any) { return this._performBinaryExpression({ op: 'lessThanOrEqual' }, ex); }
    public greaterThan(ex: any) { return this._performBinaryExpression({ op: 'greaterThan' }, ex); }
    public greaterThanOrEqual(ex: any) { return this._performBinaryExpression({ op: 'greaterThanOrEqual' }, ex); }

    // Expression constructors (Nary)
    protected _performNaryExpression(newValue: ExpressionValue, otherExs: any[]): Expression {
      if (!otherExs.length) throw new Error('must have at least one argument');
      for (var i = 0; i < otherExs.length; i++) {
        var otherEx = otherExs[i];
        if (Expression.isExpression(otherEx)) continue;
        otherExs[i] = Expression.fromJSLoose(otherEx);
      }
      newValue.operands = [this].concat(otherExs);
      return new (Expression.classMap[newValue.op])(newValue);
    }

    public add(...exs: any[]) { return this._performNaryExpression({ op: 'add' }, exs); }
    public subtract(...exs: any[]) {
      if (!exs.length) throw new Error('must have at least one argument');
      for (var i = 0; i < exs.length; i++) {
        var ex = exs[i];
        if (Expression.isExpression(ex)) continue;
        exs[i] = Expression.fromJSLoose(ex);
      }
      var newExpression: Expression = exs.length === 1 ? exs[0] : new AddExpression({ op: 'add', operands: exs });
      return this._performNaryExpression(
        { op: 'add' },
        [new NegateExpression({ op: 'negate', operand: newExpression})]
      );
    }

    public multiply(...exs: any[]) { return this._performNaryExpression({ op: 'multiply' }, exs); }
    public divide(...exs: any[]) {
      if (!exs.length) throw new Error('must have at least one argument');
      for (var i = 0; i < exs.length; i++) {
        var ex = exs[i];
        if (Expression.isExpression(ex)) continue;
        exs[i] = Expression.fromJSLoose(ex);
      }
      var newExpression: Expression = exs.length === 1 ? exs[0] : new MultiplyExpression({ op: 'add', operands: exs });
      return this._performNaryExpression(
        { op: 'multiply' },
        [new ReciprocateExpression({ op: 'reciprocate', operand: newExpression})]
      );
    }

    public and(...exs: any[]) { return this._performNaryExpression({ op: 'and' }, exs); }
    public or(...exs: any[]) { return this._performNaryExpression({ op: 'or' }, exs); }

    /**
     * Checks for references and returns the list of alterations that need to be made to the expression
     *
     * @param typeContext the context inherited from the parent
     * @param alterations the accumulation of the alterations to be made (output)
     * @returns the resolved type of the expression
     * @private
     */
    public _fillRefSubstitutions(typeContext: any, alterations: Alteration[]): any {
      return typeContext;
    }

    /**
     * Rewrites the expression with all the references typed correctly and resolved to the correct parental level
     *
     * @param typeContext
     * @returns {Expression}
     */
    public referenceCheck(typeContext: any) {
      var alterations: Alteration[] = [];
      this._fillRefSubstitutions(typeContext, alterations); // This return the final type
      function substitutionFn(ex: Expression): Expression {
        if (!ex.isOp('ref')) return null;
        for (var i = 0; i < alterations.length; i++) {
          var alteration = alterations[i];
          if (ex === alteration.from) return alteration.to;
        }
        return null;
      }
      return this.substitute(substitutionFn, 0);
    }

    /**
     * Resolves one level of dependencies that refer outside of this expression.
     *
     * @param context The context containing the values to resolve to
     * @param leaveIfNotFound If the reference is not in the context leave it (instead of throwing and error)
     * @return The resolved expression
     */
    public resolve(context: Datum, leaveIfNotFound: boolean = false): Expression {
      return this.substitute((ex: Expression, genDiff: number) => {
        if (ex instanceof RefExpression) {
          var refGen = ex.generations.length;
          if (genDiff === refGen) {
            var foundValue: any = null;
            var valueFound: boolean = false;
            if (context.hasOwnProperty(ex.name)) {
              foundValue = context[ex.name];
              valueFound = true;
            } else if (context.$def && context.$def.hasOwnProperty(ex.name)) {
              foundValue = context.$def[ex.name];
              valueFound = true;
            } else {
              if (leaveIfNotFound) {
                valueFound = false;
              } else {
                throw new Error('could not resolve ' + ex.toString() + ' because is was not in the context');
              }
            }

            if(valueFound) {
              return new LiteralExpression({op: 'literal', value: foundValue});
            }
          } else if (genDiff < refGen) {
            throw new Error('went too deep during resolve on: ' + ex.toString());
          }
        }
        return null;
      }, 0);
    }

    // Evaluation
    public compute(drivers: Lookup<Driver> = null) {
      var deferred = <Q.Deferred<Dataset>>Q.defer();

      var simple = this.simplify();
      if (drivers) {
        var driverObjects: Driver[] = [];
        Object.keys(drivers).forEach((driverName) => {
          var driver = drivers[driverName];
          if (driverObjects.indexOf(driver) === -1) driverObjects.push(driver);
        });
        if (driverObjects.length !== 1) {
          deferred.reject(new Error('must have exactly one driver defined (for now)'));
          return deferred.promise;
        }
        return driverObjects[0](simple);
      } else {
        if (simple instanceof LiteralExpression) {
          deferred.resolve(simple.value);
        } else if (simple instanceof ActionsExpression || simple instanceof LabelExpression) {
          deferred.resolve(simple.evaluate());
        } else {
          deferred.reject(new Error('can not handle that yet: ' + simple.op));
          // ToDo: implement logic
        }
        return deferred.promise;
      }
    }
  }
  check = Expression;



// =====================================================================================
// =====================================================================================

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

// =====================================================================================
// =====================================================================================

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

// =====================================================================================
// =====================================================================================

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
        var value = this.valueOf();
        value.operands = nonLiteralOperands;
        return new (Expression.classMap[this.op])(value);
      } else {
        return literalExpression
      }
    }

    public getReferences(): string[] {
      return Array.prototype.concat.apply([], this.operands.map((operand) => operand.getReferences())).sort();
    }

    public getOperandOfType(type: string): Expression[] {
      return this.operands.filter((operand) => operand.isOp(type));
    }

    public substitute(substitutionFn: SubstitutionFn, genDiff: number): Expression {
      var sub = substitutionFn(this, genDiff);
      if (sub) return sub;
      var subOperands = this.operands.map((operand) => operand.substitute(substitutionFn, genDiff));
      if (this.operands.every((op, i) => op === subOperands[i])) return this;
      var value = this.valueOf();
      value.operands = subOperands;
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
