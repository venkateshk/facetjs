module Core {
  export interface DruidFilterAndIntervals {
    filter: Druid.Filter;
    intervals: string[];
  }

  export interface DruidSplit {
    queryType: string;
    granularity: any;
    dimension?: any;
    dimensions?: any[];
    postProcess: PostProcess;
  }

  interface LabelProcess {
    (v: any): any;
  }

  export interface AggregationsAndPostAggregations {
    aggregations: Druid.Aggregation[];
    postAggregations: Druid.PostAggregation[];
  }

  function correctTimeBoundaryResult(result: Druid.TimeBoundaryResults): boolean {
    return Array.isArray(result) && result.length === 0;
  }

  function correctTimeseriesResult(result: Druid.TimeseriesResults): boolean {
    return Array.isArray(result) && (result.length === 0 || typeof result[0].result === 'object');
  }

  function correctTopNResult(result: Druid.DruidResults): boolean {
    return Array.isArray(result) && (result.length === 0 || Array.isArray(result[0].result));
  }

  function correctGroupByResult(result: Druid.GroupByResults): boolean {
    return Array.isArray(result) && (result.length === 0 || typeof result[0].event === 'object');
  }

  function makePostProcessTimeBoundary(applies: ApplyAction[]): PostProcess {
    return (res: Druid.TimeBoundaryResults): NativeDataset => {
      if (!correctTimeBoundaryResult(res)) {
        var err = new Error("unexpected result from Druid (timeBoundary)");
        (<any>err).result = res; // ToDo: special error type
        throw err;
      }

      var result = res[0].result;
      var datum: Datum = {};
      for (var i = 0; i < applies.length; i++) {
        var apply = applies[i];
        var name = apply.name;
        var aggregate = (<AggregateExpression>apply.expression).fn;
        if (typeof result === 'string') {
          datum[name] = new Date(result);
        } else {
          if (aggregate === 'max') {
            datum[name] = new Date(<string>(result['maxIngestedEventTime'] || result['maxTime']));
          } else {
            datum[name] = new Date(<string>(result['minTime']));
          }
        }
      }

      return new NativeDataset({source: 'native', data: [datum]});
    };
  }

  function postProcessTotal(res: Druid.TimeseriesResults): NativeDataset {
    if (!correctTimeseriesResult(res)) {
      var err = new Error("unexpected result from Druid (all)");
      (<any>err).result = res; // ToDo: special error type
      throw err;
    }
    return new NativeDataset({ source: 'native', data: [res[0].result] });
  }

  function makePostProcessTimeseries(duration: Duration, timezone: Timezone, label: string): PostProcess {
    return (res: Druid.TimeseriesResults): NativeDataset => {
      if (!correctTimeseriesResult(res)) {
        var err = new Error("unexpected result from Druid (timeseries)");
        (<any>err).result = res; // ToDo: special error type
        throw err;
      }
      //var warp = split.warp;
      //var warpDirection = split.warpDirection;
      var canonicalDurationLengthAndThenSome = duration.getCanonicalLength() * 1.5;
      return new NativeDataset({
        source: 'native',
        data: res.map((d: any, i: number) => {
          var rangeStart = new Date(d.timestamp);
          var next = res[i + 1];
          var nextTimestamp: Date;
          if (next) {
            nextTimestamp = new Date(next.timestamp);
          }

          var rangeEnd = (nextTimestamp && rangeStart.valueOf() < nextTimestamp.valueOf() &&
                          nextTimestamp.valueOf() - rangeStart.valueOf() < canonicalDurationLengthAndThenSome) ?
                          nextTimestamp : duration.move(rangeStart, timezone, 1);

          //if (warp) {
          //  rangeStart = warp.move(rangeStart, timezone, warpDirection);
          //  range//End = warp.move(rangeEnd, timezone, warpDirection);
          //}

          var datum: Datum = d.result;
          datum[label] = new TimeRange({ start: rangeStart, end: rangeEnd });
          return datum;
        })
      });
    }
  }

  function postProcessNumberBucketFactory(rangeSize: number): LabelProcess {
    return (v: any) => {
      var start = Number(v);
      return new NumberRange({
        start: start,
        end: Legacy.driverUtil.safeAdd(start, rangeSize)
      });
    }
  }

  function postProcessTopNFactory(labelProcess: LabelProcess, label: string): PostProcess {
    return (res: Druid.DruidResults): NativeDataset => {
      if (!correctTopNResult(res)) {
        var err = new Error("unexpected result from Druid (topN)");
        (<any>err).result = res; // ToDo: special error type
        throw err;
      }
      var data = res.length ? res[0].result : [];
      if (labelProcess) {
        return new NativeDataset({
          source: 'native',
          data: data.map((d: Datum) => {
            var v: any = d[label];
            if (String(v) === "null") {
              v = null;
            } else {
              v = labelProcess(v);
            }
            d[label] = v;
            return d;
          })
        });
      } else {
        return new NativeDataset({source: 'native', data: data});
      }
    };
  }

  function postProcessGroupBy(res: Druid.GroupByResults): NativeDataset {
    if (!correctGroupByResult(res)) {
      var err = new Error("unexpected result from Druid (groupBy)");
      (<any>err).result = res; // ToDo: special error type
      throw err;
    }
    return new NativeDataset({
      source: 'native',
      data: res.map((r) => r.event)
    });
  }

  function postProcessIntrospectFactory(timeAttribute: string): IntrospectPostProcess {
    return (res: Druid.DatasourceIntrospectResult): Lookup<AttributeInfo> => {
      var attributes: Lookup<AttributeInfo> = Object.create(null);
      attributes[timeAttribute] = new AttributeInfo({ type: 'TIME' });
      res.dimensions.forEach((dimension) => {
        attributes[dimension] = new AttributeInfo({ type: 'STRING' });
      });
      res.metrics.forEach((metric) => {
        attributes[metric] = new AttributeInfo({ type: 'NUMBER', filterable: false, splitable: false });
      });
      return attributes;
    }
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

    public dataSource: string | string[];
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

    public equals(other: DruidDataset): boolean {
      return super.equals(other) &&
        String(this.dataSource) === String(other.dataSource) &&
        this.timeAttribute === other.timeAttribute &&
        this.forceInterval === other.forceInterval &&
        this.approximate === other.approximate &&
        this.context === other.context;
    }

    public getId(): string {
      return super.getId() + ':' + this.dataSource;
    }

    // -----------------

    public canHandleFilter(ex: Expression): boolean {
      return true;
    }

    public canHandleTotal(): boolean {
      return true;
    }

    public canHandleSplit(ex: Expression): boolean {
      return true;
    }

    public canHandleSort(sortAction: SortAction): boolean {
      if (this.split instanceof TimeBucketExpression) {
        var sortExpression = sortAction.expression;
        if (sortExpression instanceof RefExpression) {
          return sortExpression.name === this.key;
        } else {
          return false;
        }
      } else {
        return true;
      }
    }

    public canHandleLimit(limitAction: LimitAction): boolean {
      return !(this.split instanceof TimeBucketExpression);
    }

    public canHandleHavingFilter(ex: Expression): boolean {
      return !this.limit;
    }

    // -----------------

    public getDruidDataSource(): string | Druid.DataSource {
      var dataSource = this.dataSource;
      if (Array.isArray(dataSource)) {
        return {
          type: "union",
          dataSources: <string[]>dataSource
        };
      } else {
        return <string>dataSource;
      }
    }

    public canUseNativeAggregateFilter(filterExpression: Expression): boolean {
      if (filterExpression.type !== 'BOOLEAN') throw new Error("must be a BOOLEAN filter");

      return filterExpression.every((ex) => {
        if (ex instanceof IsExpression) {
          return ex.lhs.isOp('ref') && ex.rhs.isOp('literal')
        } else if (ex instanceof InExpression) {
          return ex.lhs.isOp('ref') && ex.rhs.isOp('literal')
        } else if (ex.isOp('not') || ex.isOp('and') || ex.isOp('or')) {
          return null; // search within
        }
        return false
      });
    }

    public timelessFilterToDruid(filter: Expression): Druid.Filter {
      if (filter.type !== 'BOOLEAN') throw new Error("must be a BOOLEAN filter");
      var attributeInfo: AttributeInfo;

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
          attributeInfo = this.attributes[lhs.name];
          return {
            type: "selector",
            dimension: lhs.name,
            value: attributeInfo.serialize(rhs.value)
          };
        } else {
          throw new Error("can not convert " + filter.toString() + " to Druid filter");
        }

      } else if (filter instanceof InExpression) {
        var lhs = filter.lhs;
        var rhs = filter.rhs;
        if (lhs instanceof RefExpression && rhs instanceof LiteralExpression) {
          attributeInfo = this.attributes[lhs.name];
          var rhsType = rhs.type;
          if (rhsType === 'SET/STRING') {
            return {
              type: "or",
              fields: rhs.value.getValues().map((value: string) => {
                return {
                  type: "selector",
                  dimension: lhs.name,
                  value: attributeInfo.serialize(value)
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

      } else if (filter instanceof MatchExpression) {
        var operand = filter.operand;
        if (operand instanceof RefExpression) {
          return {
            type: "regex",
            dimension: operand.name,
            pattern: filter.regexp
          };
        } else {
          throw new Error("can not convert " + filter.toString() + " to Druid filter");
        }

      } else if (filter instanceof ContainsExpression) {
        var lhs = filter.lhs;
        var rhs = filter.rhs;
        if (lhs instanceof RefExpression && rhs instanceof LiteralExpression) {
          return {
            type: "search",
            dimension: lhs.name,
            query: {
              type: "fragment",
              values: [rhs.value]
            }
          };
        } else {
          throw new Error(`can not express ${rhs.toString()} in SQL`);
        }

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

    public getBucketingDimension(attributeInfo: RangeAttributeInfo, numberBucket: NumberBucketExpression): Druid.ExtractionFn {
      var regExp = attributeInfo.getMatchingRegExpString();
      if (numberBucket && numberBucket.offset === 0 && numberBucket.size === attributeInfo.rangeSize) numberBucket = null;
      var bucketing = '';
      if (numberBucket) {
        bucketing = 's=' + Legacy.driverUtil.continuousFloorExpression('s', 'Math.floor', numberBucket.size, numberBucket.offset) + ';';
      }
      return {
        type: "javascript",
        'function':
`function(d) {
var m = d.match(${regExp});
if(!m) return 'null';
var s = +m[1];
if(!(Math.abs(+m[2] - s - ${attributeInfo.rangeSize}) < 1e-6)) return 'null'; ${bucketing}
var parts = String(Math.abs(s)).split('.');
parts[0] = ('000000000' + parts[0]).substr(-10);
return (start < 0 ?'-':'') + parts.join('.');
}`
      };
    }

    public isTimeRef(ex: Expression) {
      return ex instanceof RefExpression && ex.name === this.timeAttribute;
    }

    public splitToDruid(): DruidSplit {
      var splitExpression = this.split;
      var label = this.key;

      var queryType: string;
      var dimension: any = null;
      var dimensions: any[] = null;
      var granularity: any = 'all';
      var postProcess: PostProcess = null;

      if (splitExpression instanceof RefExpression) {
        var dimensionSpec = (splitExpression.name === label) ?
                            label : { type: "default", dimension: splitExpression.name, outputName: label };

        if (this.havingFilter.equals(Expression.TRUE) && this.limit && this.approximate) {
          var attributeInfo = this.attributes[splitExpression.name];
          queryType = 'topN';
          if (attributeInfo instanceof RangeAttributeInfo) {
            dimension = {
              type: "extraction",
              dimension: splitExpression.name,
              outputName: label,
              dimExtractionFn: this.getBucketingDimension(attributeInfo, null)
            };
            postProcess = postProcessTopNFactory(postProcessNumberBucketFactory(attributeInfo.rangeSize), label);
          } else {
            dimension = dimensionSpec;
            postProcess = postProcessTopNFactory(null, null);
          }

        } else {
          queryType = 'groupBy';
          dimensions = [dimensionSpec];
          postProcess = postProcessGroupBy;

        }

      } else if (splitExpression instanceof TimeBucketExpression) {
        if (this.isTimeRef(splitExpression.operand)) {
          queryType = 'timeseries';
          granularity = {
            type: "period",
            period: splitExpression.duration.toString(),
            timeZone: splitExpression.timezone.toString()
          };
          postProcess = makePostProcessTimeseries(splitExpression.duration, splitExpression.timezone, label);

        } else {
          throw new Error(`can not convert complex time bucket: ${splitExpression.operand.toString()}`)
        }

      } else if (splitExpression instanceof NumberBucketExpression) {
        var refExpression = splitExpression.operand;
        if (refExpression instanceof RefExpression) {
          var attributeInfo = this.attributes[refExpression.name];
          queryType = "topN";
          switch (attributeInfo.type) {
            case 'NUMBER':
              var floorExpression = Legacy.driverUtil.continuousFloorExpression("d", "Math.floor", splitExpression.size, splitExpression.offset);
              dimension = {
                type: "extraction",
                dimension: refExpression.name,
                outputName: label,
                dimExtractionFn: {
                  type: "javascript",
                  'function': `function(d){d=Number(d); if(isNaN(d)) return 'null'; return ${floorExpression};}`
                }
              };
              postProcess = postProcessTopNFactory(Number, label);
              break;

            case 'NUMBER_RANGE':
              dimension = {
                type: "extraction",
                dimension: refExpression.name,
                outputName: label,
                dimExtractionFn: this.getBucketingDimension(<RangeAttributeInfo>attributeInfo, splitExpression)
              };
              postProcess = postProcessTopNFactory(postProcessNumberBucketFactory(splitExpression.size), label);
              break;

            default:
              throw new Error("can not number bucket an attribute of type: " + attributeInfo.type)
          }

        } else {
          throw new Error('can not convert complex number bucket: ' + refExpression.toString())
        }

      } else {
        throw new Error('can not convert expression: ' + splitExpression.toString())
      }

      return {
        queryType: queryType,
        granularity: granularity,
        dimension: dimension,
        dimensions: dimensions,
        postProcess: postProcess
      };
    }

    public operandsToArithmetic(operands: Expression[], fn: string): Druid.PostAggregation {
      if (operands.length === 1) {
        return this.expressionToPostAggregation(operands[0]);
      } else {
        return {
          type: 'arithmetic',
          fn: fn,
          fields: operands.map(this.expressionToPostAggregation, this)
        };
      }
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
      } else if (ex instanceof AddExpression || ex instanceof MultiplyExpression) {
        var fn: string;
        var antiFn: string;
        var opposite: string;
        var zero: number;
        if (ex instanceof AddExpression) {
          fn = '+';
          antiFn = '-';
          opposite = 'negate';
          zero = 0;
        } else {
          fn = '*';
          antiFn = '/';
          opposite = 'reciprocate';
          zero = 1;
        }
        var additive = ex.operands.filter((o) => o.op !== opposite);
        var subtractive = ex.operands.filter((o) => o.op === opposite);
        if (!additive.length) additive.push(new LiteralExpression({ op: 'literal', value: zero }));

        if (subtractive.length) {
          return {
            type: 'arithmetic',
            fn: antiFn,
            fields: [
              this.operandsToArithmetic(additive, fn),
              this.operandsToArithmetic(subtractive.map((op) => (<UnaryExpression>op).operand), fn)
            ]
          };
        } else {
          return this.operandsToArithmetic(additive, fn);
        }

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

    public havingFilterToDruid(filter: Expression): Druid.Having {
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
          return {
            type: "equalTo",
            aggregation: lhs.name,
            value: rhs.value
          };

        } else {
          throw new Error(`can not convert ${filter.toString()} to Druid filter`);
        }

      } else if (filter instanceof InExpression) {
        var lhs = filter.lhs;
        var rhs = filter.rhs;
        if (lhs instanceof RefExpression && rhs instanceof LiteralExpression) {
          var rhsType = rhs.type;
          if (rhsType === 'SET/STRING') {
            return {
              type: "or",
              fields: rhs.value.getValues().map((value: string) => {
                return {
                  type: "equalTo",
                  aggregation: lhs.name,
                  value: value
                }
              })
            };

          } else if (rhsType === 'NUMBER_RANGE') {
            throw new Error("to do");

          } else if (rhsType === 'TIME_RANGE') {
            throw new Error("can not time filter on non-primary time dimension");

          } else {
            throw new Error("not supported " + rhsType);
          }
        } else {
          throw new Error(`can not convert ${filter.toString()} to Druid having filter`);
        }

      } else if (filter instanceof LessThanExpression) {
        var lhs = filter.lhs;
        var rhs = filter.rhs;
        if (lhs instanceof RefExpression && rhs instanceof LiteralExpression) {
          return {
            type: "lessThan",
            aggregation: lhs.name,
            value: rhs.value
          }
        }

        if (lhs instanceof LiteralExpression && rhs instanceof RefExpression) {
          return {
            type: "greaterThan",
            aggregation: rhs.name,
            value: lhs.value
          }
        }

      } else if (filter instanceof NotExpression) {
        return {
          type: "not",
          field: this.havingFilterToDruid(filter.operand)
        };

      } else if (filter instanceof AndExpression || filter instanceof OrExpression) {
        return {
          type: filter.op,
          fields: filter.operands.map(this.havingFilterToDruid, this)
        };

      } else {
        throw new Error(`could not convert filter ${filter.toString()} to Druid filter`);
      }
    }

    public isMinMaxTimeApply(apply: ApplyAction): boolean {
      var applyExpression = apply.expression;
      if (applyExpression instanceof AggregateExpression) {
        return this.isTimeRef(applyExpression.attribute) &&
          (applyExpression.fn === "min" || applyExpression.fn === "max");
      } else {
        return false;
      }
    }

    public getTimeBoundaryQueryAndPostProcess(): QueryAndPostProcess<Druid.Query> {
      var druidQuery: Druid.Query = {
        queryType: "timeBoundary",
        dataSource: this.getDruidDataSource()
      };

      //if (queryBuilder.hasContext()) {
      //  druidQuery.context = queryBuilder.context;
      //}

      var applies = this.applies;
      if (applies.length === 1) {
        // Max time only
        druidQuery.bound = (<AggregateExpression>applies[0].expression).fn + "Time";
        //if (this.useDataSourceMetadata) {
        //  druidQuery.queryType = "dataSourceMetadata";
        //}
      }

      return {
        query: druidQuery,
        postProcess: makePostProcessTimeBoundary(this.applies)
      };
    }

    public getQueryAndPostProcess(): QueryAndPostProcess<Druid.Query> {
      if (this.applies && this.applies.every(this.isMinMaxTimeApply, this)) {
        return this.getTimeBoundaryQueryAndPostProcess();
      }

      var druidQuery: Druid.Query = {
        queryType: 'timeseries',
        dataSource: this.getDruidDataSource(),
        intervals: null,
        granularity: 'all'
      };

      var filterAndIntervals = this.filterToDruid(this.filter);
      druidQuery.intervals = filterAndIntervals.intervals;
      if (filterAndIntervals.filter) {
        druidQuery.filter = filterAndIntervals.filter;
      }

      switch (this.mode) {
        case 'raw':
          druidQuery.queryType = 'select';
          druidQuery.dimensions = [];
          druidQuery.metrics = [];
          druidQuery.pagingSpec = {
            "pagingIdentifiers": {},
            "threshold": 10000
          };
          
          return {
            query: druidQuery,
            postProcess: postProcessTotal
          };

        case 'total':
          var aggregationsAndPostAggregations = this.applyToDruid(this.applies);
          if (aggregationsAndPostAggregations.aggregations.length) {
            druidQuery.aggregations = aggregationsAndPostAggregations.aggregations;
          }
          if (aggregationsAndPostAggregations.postAggregations.length) {
            druidQuery.postAggregations = aggregationsAndPostAggregations.postAggregations;
          }

          return {
            query: druidQuery,
            postProcess: postProcessTotal
          };

        case 'split':
          var aggregationsAndPostAggregations = this.applyToDruid(this.applies);
          if (aggregationsAndPostAggregations.aggregations.length) {
            druidQuery.aggregations = aggregationsAndPostAggregations.aggregations;
          }
          if (aggregationsAndPostAggregations.postAggregations.length) {
            druidQuery.postAggregations = aggregationsAndPostAggregations.postAggregations;
          }

          var splitSpec = this.splitToDruid();
          druidQuery.queryType = splitSpec.queryType;
          druidQuery.granularity = splitSpec.granularity;
          if (splitSpec.dimension) druidQuery.dimension = splitSpec.dimension;
          if (splitSpec.dimensions) druidQuery.dimensions = splitSpec.dimensions;
          var postProcess = splitSpec.postProcess;

          // Combine
          switch (druidQuery.queryType) {
            case 'timeseries':
              var split = <TimeBucketExpression>this.split;
              if (this.sort && (this.sort.direction !== 'ascending' || this.sort.refName() !== this.key)) {
                throw new Error('can not sort within timeseries query');
              }
              if (this.limit) {
                throw new Error('can not limit within timeseries query');
              }
              break;

            case 'topN':
              var sortAction = this.sort;
              var metric: any = (<RefExpression>sortAction.expression).name;
              if (this.sortOrigin === 'label') {
                metric = {type: 'lexicographic'};
              }
              if (sortAction.direction === 'ascending') {
                metric = {type: "inverted", metric: metric};
              }
              druidQuery.metric = metric;
              if (this.limit) {
                druidQuery.threshold = this.limit.limit;
              }
              break;

            case 'groupBy':
              var sortAction = this.sort;
              druidQuery.limitSpec = {
                type: "default",
                limit: 500000,
                columns: [sortAction ? (<RefExpression>sortAction.expression).name : this.key]
              };
              if (this.limit) {
                druidQuery.limitSpec.limit = this.limit.limit;
              }
              if (!this.havingFilter.equals(Expression.TRUE)) {
                druidQuery.having = this.havingFilterToDruid(this.havingFilter);
              }
              break;
          }

          return {
            query: druidQuery,
            postProcess: postProcess
          };

        default:
          throw new Error("can not get query for: " + this.mode);
      }
    }

    public getIntrospectQueryAndPostProcess(): IntrospectQueryAndPostProcess<Druid.Query> {
      return {
        query: {
          queryType: 'introspect',
          dataSource: this.getDruidDataSource()
        },
        postProcess: postProcessIntrospectFactory(this.timeAttribute)
      };
    }
  }
  Dataset.register(DruidDataset);
}
