module Core {
  export interface DruidFilterAndIntervals {
    filter: Druid.Filter;
    intervals: string[];
  }

  export interface DruidSplit {
    queryType: string;
    dimension: any;
    granularity: any;
  }

  export interface AggregationsAndPostAggregations {
    aggregations: Druid.Aggregation[];
    postAggregations: Druid.PostAggregation[];
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

    public canUseNativeAggregateFilter(filterExpression: Expression): boolean {
      if (filterExpression.type !== 'BOOLEAN') throw new Error("must be a BOOLEAN filter");

      return filterExpression.every((ex) => {
        if (ex instanceof IsExpression) {
          return ex.lhs.isOp('ref') && ex.rhs.isOp('literal')
        } else if (ex instanceof InExpression) {
          return ex.lhs.isOp('ref') && ex.rhs.isOp('literal')
        } else if (ex.isOp('literal') || ex.isOp('ref') || ex.isOp('not') || ex.isOp('and') || ex.isOp('or')) {
          return true;
        }
        return false
      });
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
          throw new Error("can not convert " + filter.toString() + " to Druid interval");
        }
      } else {
        throw new Error("can not convert " + filter.toString() + " to Druid interval");
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
        var sep = filter.separateViaAnd(this.timeAttribute);
        if (!sep) throw new Error("could not separate time filter in " + filter.toString());

        return {
          intervals: this.timeFilterToIntervals(sep.included),
          filter: this.timelessFilterToDruid(sep.excluded)
        }
      }
    }

    public splitToDruid(splitExpression: Expression, label: string): DruidSplit {
      var queryType: string;
      var dimension: any = null;
      var granularity: any = 'all';

      if (splitExpression instanceof RefExpression) {
        //var attributeMeta = this.getAttributeMeta(splitExpression.name);
        queryType = 'topN';
        if (splitExpression.name === label) {
          dimension = label
        } else {
          dimension = {
            type: "default",
            dimension: splitExpression.name,
            outputName: label
          }
        }

      } else if (splitExpression instanceof TimeBucketExpression) {
        var refExpression = splitExpression.operand;
        if (refExpression instanceof RefExpression) {
          if (refExpression.name === this.timeAttribute) {
            queryType = 'timeseries';
            granularity = {
              type: "period",
              period: splitExpression.duration.toString(),
              timeZone: splitExpression.timezone.toString()
            }
          } else {
            // ToDo: add this maybe?
            throw new Error('can not time bucket non time dimension: ' + refExpression.toString())
          }

        } else {
          throw new Error('can not convert complex time bucket: ' + refExpression.toString())
        }

      } else if (splitExpression instanceof NumberBucketExpression) {
        var refExpression = splitExpression.operand;
        if (refExpression instanceof RefExpression) {
          var attributeMeta = this.getAttributeMeta(refExpression.name);
          switch (attributeMeta.type) {
            case 'default': // ToDo: fix this
            case 'NUMBER':
              var floorExpression = Legacy.driverUtil.continuousFloorExpression("d", "Math.floor", splitExpression.size, splitExpression.offset);

              queryType = "topN";
              dimension = {
                type: "extraction",
                dimension: refExpression.name,
                outputName: label,
                dimExtractionFn: {
                  type: "javascript",
                  "function": "function(d){d=Number(d); if(isNaN(d)) return 'null'; return " + floorExpression + ";}"
                }
              };
              break;

            case 'NUMBER_RANGE':
              // ToDo: fill in
              break;

            default:
              throw new Error("can not number bucket an attribute of type: " + attributeMeta.type)
          }

        } else {
          throw new Error('can not convert complex number bucket: ' + refExpression.toString())
        }

      } else {
        dimension = {
          type: "fake",
          outputName: label
        }
      }

      return {
        queryType: queryType,
        dimension: dimension,
        granularity: granularity
      };
    }

    public expressionToPostAggregation(ex: Expression): Druid.PostAggregation {
      if (ex instanceof RefExpression) {
        return {
          type: 'fieldAccess', // or "hyperUniqueCardinality"
          fieldName: ex.name
        };
      } else if (ex instanceof LiteralExpression) {
        if (ex.type !== 'NUMBER') throw new Error("must be a NUMBER type");
        return {
          type: 'constant',
          value: ex.value
        };
      } else if (ex instanceof AddExpression) {
        return {
          type: 'arithmetic',
          fn: '+',
          fields: ex.operands.map(this.expressionToPostAggregation, this)
        };
      } else if (ex instanceof MultiplyExpression) {
        return {
          type: 'arithmetic',
          fn: '*',
          fields: ex.operands.map(this.expressionToPostAggregation, this)
        };
      } else {
        throw new Error("can not convert expression to post agg: " + ex.toString());
      }
    }

    public actionToPostAggregation(action: Action): Druid.PostAggregation {
      if (action instanceof ApplyAction || action instanceof DefAction) {
        var postAgg = this.expressionToPostAggregation(action.expression);
        postAgg.name = action.name;
        return postAgg;
      } else {
        throw new Error("must be a def or apply action");
      }
    }

    public actionToAggregation(action: Action): Druid.Aggregation {
      if (action instanceof ApplyAction || action instanceof DefAction) {
        var aggregateExpression = action.expression;
        if (aggregateExpression instanceof AggregateExpression) {
          var attribute = aggregateExpression.attribute;
          var aggregation: Druid.Aggregation = {
            name: action.name,
            type: aggregateExpression.fn === "sum" ? "doubleSum" : aggregateExpression.fn
          };
          if (aggregateExpression.fn !== 'count') {
            if (attribute instanceof RefExpression) {
              aggregation.fieldName = attribute.name;
            } else if (attribute) {
              throw new Error('can not support derived attributes (yet)');
            }
          }

          // See if we want to do a filtered aggregate
          var aggregateOperand = aggregateExpression.operand;
          if (aggregateOperand instanceof ActionsExpression &&
            aggregateOperand.actions.length === 1 &&
            aggregateOperand.actions[0] instanceof FilterAction &&
            this.canUseNativeAggregateFilter(aggregateOperand.actions[0].expression)) {
            aggregation = {
              type: "filtered",
              name: action.name,
              filter: this.timelessFilterToDruid(aggregateOperand.actions[0].expression),
              aggregator: aggregation
            };
          }

          return aggregation;

        } else {
          throw new Error('can not support non aggregate aggregateExpression');
        }
      } else {
        throw new Error("must be a def or apply action");
      }
    }

    public breakUpApplies(applies: ApplyAction[]): Action[] {
      var knownExpressions: Lookup<string> = {};
      var actions: Action[] = [];
      var nameIndex = 0;

      applies.forEach((apply) => {
        actions.push(new ApplyAction({
          action: 'apply',
          name: apply.name,
          expression: apply.expression.substitute((ex: Expression, depth: number) => {
            if (ex instanceof AggregateExpression) {
              var key = ex.toString();
              if (depth === 0) {
                knownExpressions[key] = apply.name;
                return null;
              }

              var name: string;
              if (hasOwnProperty(knownExpressions, key)) {
                name = knownExpressions[key];
              } else {
                name = '_sd_' + nameIndex;
                nameIndex++;
                actions.push(new DefAction({
                  action: 'def',
                  name: name,
                  expression: ex
                }));
                knownExpressions[key] = name;
              }

              return new RefExpression({
                op: 'ref',
                name: name,
                type: 'NUMBER'
              });
            }
          })
        }));
      });

      return actions;
    }

    public applyToDruid(applies: ApplyAction[]): AggregationsAndPostAggregations {
      var aggregations: Druid.Aggregation[] = [];
      var postAggregations: Druid.PostAggregation[] = [];

      this.breakUpApplies(applies).forEach((action) => {
        if (action.expression instanceof AggregateExpression) {
          aggregations.push(this.actionToAggregation(action));
        } else {
          postAggregations.push(this.actionToPostAggregation(action));
        }
      });

      return {
        aggregations: aggregations,
        postAggregations: postAggregations
      };
    }

    public attachPathToQuery(attachPath: AttachPoint): DatastoreQuery {
      var druidQuery: Druid.Query = {
        queryType: 'timeseries',
        dataSource: this.dataSource,
        intervals: null,
        granularity: 'all'
      };

      if (attachPath.name) {
        var queryPattern = attachPath.actions.splitPattern();
        if (!queryPattern) throw new Error("does not match splitPattern");

        var filterAndIntervals = this.filterToDruid(queryPattern.filter);
        
        var post: (v: any) => Q.Promise<any> = (v) => Q(null);

        druidQuery.intervals = filterAndIntervals.intervals;
        if (filterAndIntervals.filter) {
          druidQuery.filter = filterAndIntervals.filter;
        }

        var aggregationsAndPostAggregations = this.applyToDruid(queryPattern.applies);
        if (aggregationsAndPostAggregations.aggregations.length) {
          druidQuery.aggregations = aggregationsAndPostAggregations.aggregations;
        }
        if (aggregationsAndPostAggregations.postAggregations.length) {
          druidQuery.postAggregations = aggregationsAndPostAggregations.postAggregations;
        }

        var splitSpec = this.splitToDruid(queryPattern.split, queryPattern.label);
        druidQuery.queryType = splitSpec.queryType;
        druidQuery.granularity = splitSpec.granularity;
        if (splitSpec.dimension) druidQuery.dimension = splitSpec.dimension;

      } else {
        var queryPattern = attachPath.actions.totalPattern();
        if (!queryPattern) throw new Error("does not match totalPattern");

        var filterAndIntervals = this.filterToDruid(queryPattern.filter);

        var post: (v: any) => Q.Promise<any> = (v) => Q(null);

        druidQuery.intervals = filterAndIntervals.intervals;
        if (filterAndIntervals.filter) {
          druidQuery.filter = filterAndIntervals.filter;
        }

        var aggregationsAndPostAggregations = this.applyToDruid(queryPattern.applies);
        if (aggregationsAndPostAggregations.aggregations.length) {
          druidQuery.aggregations = aggregationsAndPostAggregations.aggregations;
        }
        if (aggregationsAndPostAggregations.postAggregations.length) {
          druidQuery.postAggregations = aggregationsAndPostAggregations.postAggregations;
        }
      }

      return {
        query: druidQuery,
        post: post
      }
    }

    public generateQueries(ex: Expression): DatastoreQuery[] {
      var attachPaths = getAttachPoints(<ActionsExpression>ex);
      return attachPaths.map(this.attachPathToQuery, this);
    }
  }
  Dataset.register(DruidDataset);
}
