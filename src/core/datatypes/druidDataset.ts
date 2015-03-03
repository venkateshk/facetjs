module Core {
  export interface DruidFilterAndIntervals {
    filter: Druid.Filter;
    intervals: string[];
  }

  export class DruidDataset extends RemoteDataset {
    static type = 'DATASET';

    static TRUE_INTERVAL = ["1000-01-01/3000-01-01"];
    static FALSE_INTERVAL = ["1000-01-01/1000-01-02"];

    static fromJS(datasetJS: any): DruidDataset {
      var value = Dataset.jsToValue(datasetJS);
      value.dataSource = datasetJS.dataSource;
      value.timeAttribute = datasetJS.timeAttribute;
      value.forceInterval = datasetJS.forceInterval;
      value.approximate = datasetJS.approximate;
      value.context = datasetJS.context;
      return new DruidDataset(value);
    }

    public dataSource: any; // ToDo: string | string[]
    public timeAttribute: string;
    public forceInterval: boolean;
    public approximate: boolean;
    public context: Lookup<any>;

    constructor(parameters: DatasetValue) {
      super(parameters, dummyObject);
      this._ensureSource("druid");
      this.dataSource = parameters.dataSource;
      this.timeAttribute = parameters.timeAttribute;
      if (typeof this.timeAttribute !== 'string') throw new Error("must have a timeAttribute");
      this.forceInterval = parameters.forceInterval;
      this.approximate = parameters.approximate;
      this.context = parameters.context;
    }

    public getAttributeMeta(attr: string): Legacy.AttributeMeta {
      return Legacy.AttributeMeta.DEFAULT
    }

    public timelessFilterToDruid(filter: Expression): Druid.Filter {
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
          field: this.timelessFilterToDruid(filter.operand)
        };
      } else if (filter instanceof AndExpression || filter instanceof OrExpression) {
        return {
          type: filter.op,
          fields: filter.operands.map(this.timelessFilterToDruid, this)
        };
      } else {
        throw new Error("could not convert filter " + filter.toString() + " to Druid filter");
      }
    }

    public timeFilterToIntervals(filter: Expression): string[] {
      if (filter.type !== 'BOOLEAN') throw new Error("must be a BOOLEAN filter");

      if (filter instanceof LiteralExpression) {
        return filter.value ? DruidDataset.TRUE_INTERVAL : DruidDataset.FALSE_INTERVAL;
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

    public filterToDruid(filter: Expression): DruidFilterAndIntervals {
      if (filter.type !== 'BOOLEAN') throw new Error("must be a BOOLEAN filter");

      if (filter.equals(Expression.FALSE)) {
        return {
          intervals: DruidDataset.FALSE_INTERVAL,
          filter: null
        }
      } else {
        var sep = filter.separateViaAnd('time'); // ToDo generalize 'time'
        if (!sep) throw new Error("could not separate time filter in " + filter.toString());

        return {
          intervals: this.timeFilterToIntervals(sep.included),
          filter: this.timelessFilterToDruid(sep.excluded)
        }
      }
    }

    public generateQuery(ex: Expression): DatastoreQuery {
      var filterAndIntervals = this.filterToDruid(Expression.TRUE);

      var post: (v: any) => Q.Promise<Dataset>;
      var druidQuery: Druid.Query = {
        queryType: 'timeseries', // For now
        dataSource: 'blah',
        intervals: filterAndIntervals.intervals
      };

      if (filterAndIntervals.filter) {
        druidQuery.filter = filterAndIntervals.filter;
      }

      if (ex instanceof ActionsExpression) {
        var operand = ex.operand;
        if (operand instanceof LiteralExpression) {
          druidQuery.granularity = 'all';

          post = (v: any): Q.Promise<Dataset> => {
            throw new Error();
          }
        } else if (operand instanceof LabelExpression) {
          druidQuery.queryType = 'topN';
          druidQuery.granularity = 'all';

          post = (v: any): Q.Promise<Dataset> => {
            throw new Error();
          }
        }
      } else {
        throw new Error("must be an actions expression");
      }

      return {
        query: druidQuery,
        post: post
      }
    }
  }
  Dataset.register(DruidDataset);
}
