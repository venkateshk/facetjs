module Core {
  export interface Capabilety {
    (ex: Expression): boolean;
  }

  export interface FilterCapabileties {
    canIs?: Capabilety;
    canAnd?: Capabilety;
    canOr?: Capabilety;
    canNot?: Capabilety;
  }

  export interface ApplyCombineCapabileties {
    canSum?: Capabilety;
    canMin?: Capabilety;
    canMax?: Capabilety;
    canGroup?: Capabilety;
  }

  export interface SplitCapabileties {
    canTotal?: ApplyCombineCapabileties;
    canSplit?: ApplyCombineCapabileties;
  }

  export interface DatastoreQuery {
    query: any;
    post: (result: any) => Q.Promise<Dataset>;
  }

  export module druidDriver {
    function getAttributeMeta(attr: string): Legacy.AttributeMeta {
      return Legacy.AttributeMeta.DEFAULT
    }

    function timelessFilterToDruid(filter: Expression): Druid.Filter {
      if (filter.type !== 'BOOLEAN') throw new Error("must be a BOOLEAN filter");
      var attributeMeta: Legacy.AttributeMeta;

      if (filter instanceof LiteralExpression) {
        if (filter.value === true) {
          return null;
        } else {
          throw new Error("should never get here");
        }
      } else if (filter instanceof IsExpression) {
        var lhs = filter.lhs;
        var rhs = filter.rhs;
        if (lhs instanceof RefExpression && rhs instanceof LiteralExpression) {
          attributeMeta = this.getAttributeMeta(lhs.name);
          return {
            type: "selector",
            dimension: lhs.name,
            value: attributeMeta.serialize(rhs.value)
          };
        } else {
          throw new Error("can not convert " + filter.toString() + " to Druid filter");
        }
      } else if (filter instanceof InExpression) {
        var lhs = filter.lhs;
        var rhs = filter.rhs;
        if (lhs instanceof RefExpression && rhs instanceof LiteralExpression) {
          attributeMeta = this.getAttributeMeta(lhs.name);
          var rhsType = rhs.type;
          if (rhsType === 'SET/STRING') {
            return {
              type: "or",
              fields: rhs.value.getValues().map((value: string) => {
                return {
                  type: "selector",
                  dimension: lhs.name,
                  value: attributeMeta.serialize(value)
                }
              })
            };
          } else if (rhsType === 'NUMBER_RANGE') {
            var range: NumberRange = rhs.value;
            var r0 = range.start;
            var r1 = range.end;
            return {
              type: "javascript",
              dimension: lhs.name,
              "function": "function(a) { a = Number(a); return " + r0 + " <= a && a < " + r1 + "; }"
            };
          } else if (rhsType === 'TIME_RANGE') {
            throw new Error("can not time filter on non-primary time dimension");
          } else {
            throw new Error("not supported " + rhsType);
          }
        } else {
          throw new Error("can not convert " + filter.toString() + " to Druid filter");
        }

      /*
        case "contains":
          return {
            type: "search",
            dimension: filter.attribute,
            query: {
              type: "fragment",
              values: [(<ContainsFilter>filter).value]
            }
          };
        case "match":
          return {
            type: "regex",
            dimension: filter.attribute,
            pattern: (<MatchFilter>filter).expression
          };
      */

      } else if (filter instanceof NotExpression) {
        return {
          type: "not",
          field: timelessFilterToDruid(filter.operand)
        };
      } else if (filter instanceof AndExpression || filter instanceof OrExpression) {
        return {
          type: filter.op,
          fields: filter.operands.map(timelessFilterToDruid)
        };
      } else {
        throw new Error("could not convert filter " + filter.toString() + " to Druid filter");
      }
    }

    var NO_INTERVAL = ["1000-01-01/3000-01-01"];
    function timeFilterToIntervals(filter: Expression): string[] {
      if (filter.type !== 'BOOLEAN') throw new Error("must be a BOOLEAN filter");

      if (filter instanceof LiteralExpression) {
        if (filter.value === true) {
          return NO_INTERVAL;
        } else {
          throw new Error("should never get here");
        }
      } else if (filter instanceof InExpression) {
        var lhs = filter.lhs;
        var rhs = filter.rhs;

        if (lhs instanceof RefExpression && rhs instanceof LiteralExpression) {
          var timeRanges: TimeRange[];
          var rhsType = rhs.type;
          if (rhsType === 'SET/TIME_RANGE') {
            timeRanges = rhs.value.getValues();
          } else if (rhsType === 'TIME_RANGE') {
            timeRanges = [rhs.value];
          } else {
            throw new Error("not supported " + rhsType + " for time filtering");
          }

          return timeRanges.map((timeRange) => timeRange.toInterval());
        } else {
          throw new Error("can not convert " + filter.toString() + " to Druid filter");
        }
      }
    }

    function filterToDruid(ex: Expression): Druid.Filter {
      throw "poo"
    }

    function makeQuery(ex: Expression): DatastoreQuery {
      throw new Error("make me");
    }
  }
}
