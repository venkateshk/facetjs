module Core {
  export interface DruidFilterAndIntervals {
    filter: Druid.Filter;
    intervals: string[];
  }

  export interface QueryPattern {
    dataSourceName: string;
    filter: Expression;
    split?: Expression;
    label?: string;
    applies: ApplyAction[];
    sort?: SortAction;
    limit?: LimitAction;
  }

  // [{ applyName: 'Cuts', label: 'Cut', value: 'good-cut' }], name: 'Carats'
  export interface PathPart {
    applyName: string;
    label: string;
    value: any;
  }

  export interface AttachPath {
    path: PathPart[];
    name: string;
    expression: Expression;
  }

  export class DruidDataset extends RemoteDataset {
    static type = 'DATASET';

    static TRUE_INTERVAL = ["1000-01-01/3000-01-01"];
    static FALSE_INTERVAL = ["1000-01-01/1000-01-02"];

    static fromJS(datasetJS: any): DruidDataset {
      var value = RemoteDataset.jsToValue(datasetJS);
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

    public valueOf(): DatasetValue {
      var value = super.valueOf();
      value.dataSource = this.dataSource;
      value.timeAttribute = this.timeAttribute;
      value.forceInterval = this.forceInterval;
      value.approximate = this.approximate;
      value.context = this.context;
      return value;
    }

    public toJS(): DatasetJS {
      var js = super.toJS();
      js.dataSource = this.dataSource;
      js.timeAttribute = this.timeAttribute;
      js.forceInterval = this.forceInterval;
      js.approximate = this.approximate;
      js.context = this.context;
      return js;
    }

    public toString(): string {
      return "DruidDataset(" + this.dataSource + ")";
    }

    public equals(other: DruidDataset): boolean {
      return super.equals(other) &&
        String(this.dataSource) === String(other.dataSource) &&
        this.timeAttribute === other.timeAttribute &&
        this.forceInterval === other.forceInterval &&
        this.approximate === other.approximate &&
        this.context === other.context;
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

    private totalPattern(ex: Expression): QueryPattern {
      if (ex instanceof ActionsExpression) {
        var operand = ex.operand;
        var actions = ex.actions;
        if (operand instanceof LiteralExpression && operand.value.basis() && actions.length > 1) {
          var action: Action = actions[0];
          var queryPattern: QueryPattern = null;
          if (action instanceof DefAction) {
            queryPattern = {
              dataSourceName: action.name,
              filter: (<RemoteDataset>(<LiteralExpression>action.expression).value).filter, // ToDo: make this a function
              applies: []
            }
          } else {
            return null;
          }

          for (var i = 1; i < actions.length; i++) {
            action = actions[i];
            if (action instanceof ApplyAction) {
              queryPattern.applies.push(action);
            } else {
              return null;
            }
          }

          return queryPattern;
        } else {
          return null;
        }
      } else {
        return null;
      }
    }

    private splitPattern(ex: Expression): QueryPattern {
      if (ex instanceof ActionsExpression) {
        var labelOperand = ex.operand;
        var actions = ex.actions;
        if (labelOperand instanceof LabelExpression && actions.length > 1) {
          var groupAggregate = labelOperand.operand;
          if (groupAggregate instanceof AggregateExpression) {
            var action: Action = actions[0];
            var queryPattern: QueryPattern = null;
            if (action instanceof DefAction) {
              queryPattern = {
                dataSourceName: action.name,
                filter: (<RemoteDataset>(<LiteralExpression>action.expression).value).filter, // ToDo: make this a function
                split: groupAggregate.attribute,
                label: labelOperand.name,
                applies: []
              }
            } else {
              return null;
            }

            for (var i = 1; i < actions.length; i++) {
              action = actions[i];
              if (action instanceof ApplyAction) {
                queryPattern.applies.push(action);
              } else if (action instanceof SortAction) {
                queryPattern.sort = action;
              } else if (action instanceof LimitAction) {
                queryPattern.limit = action;
              } else {
                return null;
              }
            }

            return queryPattern;
          } else {
            return null;
          }
        } else {
          return null;
        }
      } else {
        return null;
      }
    }

    private getAttachPaths(ex: ActionsExpression, context: Datum): AttachPath[] {
      var operand = ex.operand;
      var actions = ex.actions;

      var action = actions[0];
      if (actions.length === 1 && action instanceof ApplyAction) {

      } else {
        return [{
          path: [],
          name: null,
          expression: ex
        }]
      }
    }

    public generateQueries(ex: Expression): DatastoreQuery {
      var queryPattern: QueryPattern;
      if (queryPattern = this.totalPattern(ex)) {
        var filterAndIntervals = this.filterToDruid(queryPattern.filter);

        var post: (v: any) => Q.Promise<any> = (v) => Q.reject(new Error());
        var druidQuery: Druid.Query = {
          //context: { ex: ex.toString() },
          queryType: 'timeseries', // For now
          dataSource: this.dataSource,
          intervals: filterAndIntervals.intervals,
          granularity: 'all',
          x_aggregates: queryPattern.applies.map((ex) => ex.toJS())
        };
        if (filterAndIntervals.filter) {
          druidQuery.filter = filterAndIntervals.filter;
        }
        return {
          queries: [druidQuery],
          post: post
        }
      } else {
        var filterAndIntervals = this.filterToDruid(Expression.TRUE);

        var post: (v: any) => Q.Promise<any> = (v) => Q.reject(new Error());
        var druidQuery: Druid.Query = {
          context: { ex: ex.toString() },
          queryType: 'timeseries', // For now
          dataSource: this.dataSource,
          intervals: filterAndIntervals.intervals,
          granularity: 'blah'
        };
        return {
          queries: [druidQuery],
          post: post
        }
      }
    }
  }
  Dataset.register(DruidDataset);
}
