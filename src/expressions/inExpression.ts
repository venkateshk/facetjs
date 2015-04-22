module Facet {
  function makeInOrIs(lhs: Expression, value: any): Expression {
    var literal = new LiteralExpression({
      op: 'literal',
      value: value
    });

    var literalType = literal.type;
    var returnExpression: Expression = null;
    if (literalType === 'NUMBER_RANGE' || literalType === 'TIME_RANGE' || literalType.indexOf('SET/') === 0) {
      returnExpression = new InExpression({ op: 'in', lhs: lhs, rhs: literal });
    } else {
      returnExpression = new IsExpression({ op: 'is', lhs: lhs, rhs: literal });
    }
    return returnExpression.simplify();
  }

  export class InExpression extends BinaryExpression {
    static fromJS(parameters: ExpressionJS): InExpression {
      return new InExpression(BinaryExpression.jsToValue(parameters));
    }

    constructor(parameters: ExpressionValue) {
      super(parameters, dummyObject);
      this._ensureOp("in");
      var lhs = this.lhs;
      var rhs = this.rhs;

      if (!(rhs.canHaveType('SET')
        || (lhs.canHaveType('NUMBER') && rhs.canHaveType('NUMBER_RANGE'))
        || (lhs.canHaveType('TIME') && rhs.canHaveType('TIME_RANGE')))) {
        throw new TypeError(`in expression has a bad type combination ${lhs.type || '?'} in ${rhs.type || '?'}`);
      }

      this.type = 'BOOLEAN';
    }

    public toString(): string {
      return `${this.lhs.toString()} in ${this.rhs.toString()}`;
    }

    protected _getFnHelper(lhsFn: ComputeFn, rhsFn: ComputeFn): ComputeFn {
      var lhsType = this.lhs.type;
      var rhsType = this.rhs.type;
      if ((lhsType === 'NUMBER' && rhsType === 'SET/NUMBER_RANGE') ||
          (lhsType === 'TIME' && rhsType === 'SET/TIME_RANGE')) {
        return (d: Datum) => (<Set>(rhsFn(d))).containsWithin(lhsFn(d));
      } else {
        // Time range and set also have contains
        return (d: Datum) => (<NumberRange>(rhsFn(d))).contains(lhsFn(d));
      }
    }

    protected _getJSExpressionHelper(lhsFnJS: string, rhsFnJS: string): string {
      var lhsType = this.lhs.type;
      var rhsType = this.rhs.type;
      if ((lhsType === 'NUMBER' && rhsType === 'SET/NUMBER_RANGE') ||
        (lhsType === 'TIME' && rhsType === 'SET/TIME_RANGE')) {
        return `${rhsFnJS}.containsWithin(${lhsFnJS})`;
      } else {
        // Time range and set also have contains
        return `${rhsFnJS}.contains(${lhsFnJS})`;
      }
    }

    protected _getSQLHelper(lhsSQL: string, rhsSQL: string, dialect: SQLDialect, minimal: boolean): string {
      var rhs = this.rhs;
      var rhsType = rhs.type;
      switch (rhsType) {
        case 'NUMBER_RANGE':
          if (rhs instanceof LiteralExpression) {
            var numberRange: NumberRange = rhs.value;
            return dialect.inExpression(lhsSQL, numberToSQL(numberRange.start), numberToSQL(numberRange.end), numberRange.bounds);
          }
          throw new Error('not implemented yet');

        case 'TIME_RANGE':
          if (rhs instanceof LiteralExpression) {
            var timeRange: TimeRange = rhs.value;
            return dialect.inExpression(lhsSQL, timeToSQL(timeRange.start), timeToSQL(timeRange.end), timeRange.bounds);
          }
          throw new Error('not implemented yet');

        case 'SET/STRING':
          return `${lhsSQL} IN ${rhsSQL}`;

        default:
          throw new Error('not implemented yet');
      }
    }

    public mergeAnd(ex: Expression): Expression {
      if (ex.isOp('literal')) return ex.mergeAnd(this);

      if (!this.checkLefthandedness()) return null;
      if (!arraysEqual(this.getFreeReferences(), ex.getFreeReferences())) return null;

      if (ex instanceof IsExpression || ex instanceof InExpression) {
        if (!ex.checkLefthandedness()) return null;

        var intersect = Set.generalIntersect((<LiteralExpression>this.rhs).value, (<LiteralExpression>ex.rhs).value);
        if (intersect === null) return null;

        return makeInOrIs(this.lhs, intersect);
      }
      return null;
    }

    public mergeOr(ex: Expression): Expression {
      if (ex.isOp('literal')) return ex.mergeOr(this);

      if (!this.checkLefthandedness()) return null;
      if (!arraysEqual(this.getFreeReferences(), ex.getFreeReferences())) return null;

      if (ex instanceof IsExpression || ex instanceof InExpression) {
        if (!ex.checkLefthandedness()) return null;

        var intersect = Set.generalUnion((<LiteralExpression>this.rhs).value, (<LiteralExpression>ex.rhs).value);
        if (intersect === null) return null;

        return makeInOrIs(this.lhs, intersect);
      }
      return null;
    }

    protected _specialSimplify(simpleLhs: Expression, simpleRhs: Expression): Expression {
      if (
        simpleLhs instanceof RefExpression &&
        simpleRhs instanceof LiteralExpression &&
        simpleRhs.type.indexOf('SET/') === 0 &&
        simpleRhs.value.empty()
      ) return Expression.FALSE;
      return null;
    }
  }

  Expression.register(InExpression);
}
