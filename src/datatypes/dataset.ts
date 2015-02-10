module Core {
  export interface DatasetValue {
    dataset: string;
    data?: Datum[];
  }

  export interface DatasetJS {
    dataset: string;
    data?: Datum[];
  }

// =====================================================================================
// =====================================================================================

  var check: ImmutableClass<DatasetValue, DatasetJS>;
  export class Dataset implements ImmutableInstance<DatasetValue, DatasetJS> {
    static type = 'DATASET';

    static isDataset(candidate: any): boolean {
      return isInstanceOf(candidate, Dataset);
    }

    static classMap: Lookup<typeof Dataset> = {};

    static register(ex: typeof Dataset): void {
      var op = (<any>ex).name.replace('Dataset', '').replace(/^\w/, (s: string) => s.toLowerCase());
      Dataset.classMap[op] = ex;
    }

    static fromJS(datasetJS: DatasetJS): Dataset {
      if (!datasetJS.hasOwnProperty("dataset")) {
        throw new Error("dataset must be defined");
      }
      var dataset = datasetJS.dataset;
      if (typeof dataset !== "string") {
        throw new Error("dataset must be a string");
      }
      var ClassFn = Dataset.classMap[dataset];
      if (!ClassFn) {
        throw new Error("unsupported dataset '" + dataset + "'");
      }

      return ClassFn.fromJS(datasetJS);
    }

    public dataset: string;

    constructor(parameters: DatasetValue, dummy: Dummy = null) {
      this.dataset = parameters.dataset;
      if (dummy !== dummyObject) {
        throw new TypeError("can not call `new Dataset` directly use Dataset.fromJS instead");
      }
    }

    protected _ensureDataset(dataset: string) {
      if (!this.dataset) {
        this.dataset = dataset;
        return;
      }
      if (this.dataset !== dataset) {
        throw new TypeError("incorrect dataset '" + this.dataset + "' (needs to be: '" + dataset + "')");
      }
    }

    public valueOf(): DatasetValue {
      return {
        dataset: this.dataset
      };
    }

    public toJS(): DatasetJS {
      return {
        dataset: this.dataset
      };
    }

    public toString(): string {
      return "<Dataset:" + this.dataset + ">";
    }

    public toJSON(): DatasetJS {
      return this.toJS();
    }

    public equals(other: Dataset): boolean {
      return Dataset.isDataset(other) &&
        this.dataset === other.dataset;
    }
  }
  check = Dataset;

// =====================================================================================
// =====================================================================================

  export interface DirectionFn {
    (a: any, b: any): number;
  }

  var directionFns: Lookup<DirectionFn> = {
    ascending: (a: any, b: any): number => {
      if (a.compare) return a.comapre(b);
      return a < b ? -1 : a > b ? 1 : a >= b ? 0 : NaN;
    },
    descending: (a: any, b: any): number => {
      if (b.compare) return b.comapre(a);
      return b < a ? -1 : b > a ? 1 : b >= a ? 0 : NaN;
    }
  };

  function datumToJS(datum: Datum): Datum {
    var js: Datum = {};
    for (var k in datum) {
      if (!datum.hasOwnProperty(k)) continue;
      if (k[0] === '_') continue;
      var v: any = datum[k];
      if (v == null) {
        v = null;
      } else {
        var typeofV = typeof v;
        if (typeofV === 'object') {
          if (v.toISOString) {
            v = { type: 'DATE', value: v };
          } else {
            var type = v.constructor.type;
            v = v.toJS();
            v.type = type;
          }
        } else if (typeofV === 'number' && !isFinite(v)) {
          v = { type: 'NUMBER', value: String(v) };
        }
      }
      js[k] = v;
    }
    return js;
  }

  function datumFromJS(js: Datum): Datum {
    if (typeof js !== 'object') throw new TypeError("datum must be an object");

    var datum: Datum = {};
    for (var k in js) {
      if (!js.hasOwnProperty(k)) continue;
      var v: any = js[k];
      if (v == null) {
        v = null;
      } else if (Array.isArray(v)) {
        v = NativeDataset.fromJS({
          dataset: 'base',
          data: v
        })
      } else if (typeof v === 'object') {
        switch (v.type) {
          case 'NUMBER':
            var infinityMatch = String(v.value).match(/^([-+]?)Infinity$/);
            if (infinityMatch) {
              v = infinityMatch[1] === '-' ? -Infinity : Infinity;
            } else {
              throw new Error("bad number value '" + String(v.value) + "'");
            }
            break;

          case 'NUMBER_RANGE':
            v = NumberRange.fromJS(v);
            break;

          case 'DATE':
            v = new Date(v.value);
            break;

          case 'TIME_RANGE':
            v = TimeRange.fromJS(v);
            break;

          case 'SHAPE':
            v = Shape.fromJS(v);
            break;

          // ToDo: fill this in with the rest of the datatypes

          default:
            throw new Error('can not have an object without a `type` as a datum value')
        }
      }
      datum[k] = v;
    }

    return datum;
  }

  export class NativeDataset extends Dataset {
    static type = 'DATASET';

    static fromJS(datasetJS: DatasetJS): NativeDataset {
      return new NativeDataset({
        dataset: datasetJS.dataset,
        data: datasetJS.data.map(datumFromJS)
      })
    }

    public data: Datum[];

    constructor(parameters: DatasetValue) {
      super(parameters, dummyObject);
      this.data = parameters.data;
      this._ensureDataset("native");
      if (!Array.isArray(this.data)) {
        throw new TypeError("must have a `data` array")
      }
    }

    public valueOf(): DatasetValue {
      var value = super.valueOf();
      value.data = this.data;
      return value;
    }

    public toJS(): DatasetJS {
      var js = super.toJS();
      js.data = this.data.map(datumToJS);
      return js;
    }

    public equals(other: NativeDataset): boolean {
      return super.equals(other) &&
        this.data.length === other.data.length;
      // ToDo: probably add something else here?
    }

    // Actions
    public apply(name: string, exFn: Function): NativeDataset {
      // Note this works in place, fix that later if needed.
      var data = this.data;
      var n = data.length;
      for (var i = 0; i < n; i++) {
        var datum = data[i];
        datum[name] = exFn(datum);
      }
      return this;
    }

    public def(name: string, exFn: Function): NativeDataset {
      return this.apply('_' + name, exFn);
    }

    public filter(exFn: Function): NativeDataset {
      return new NativeDataset({
        dataset: 'native',
        data: this.data.filter((datum) => exFn(datum))
      })
    }

    public sort(exFn: Function, direction: string): NativeDataset {
      // Note this works in place, fix that later if needed.
      var directionFn = directionFns[direction];
      this.data.sort((a, b) => directionFn(exFn(a), exFn(b)));
      return this;
    }

    public limit(limit: number): NativeDataset {
      if (this.data.length <= limit) return this;
      return new NativeDataset({
        dataset: 'native',
        data: this.data.slice(0, limit)
      })
    }

    // Aggregators
    public count(): number {
      return this.data.length;
    }

    public sum(attrFn: Function): number {
      var sum = 0;
      var data = this.data;
      var n = data.length;
      for (var i = 0; i < n; i++) {
        sum += attrFn(data[i])
      }
      return sum;
    }

    public min(attrFn: Function): number {
      var min = Infinity;
      var data = this.data;
      var n = data.length;
      for (var i = 0; i < n; i++) {
        var v = attrFn(data[i]);
        if (v < min) min = v;
      }
      return min;
    }

    public max(attrFn: Function): number {
      var max = Infinity;
      var data = this.data;
      var n = data.length;
      for (var i = 0; i < n; i++) {
        var v = attrFn(data[i]);
        if (max < v) max = v;
      }
      return max;
    }

    public group(attrFn: Function): Set {
      var splits: Lookup<any> = {};
      var data = this.data;
      var n = data.length;
      for (var i = 0; i < n; i++) {
        var datum = data[i];
        var v: any = attrFn(datum);
        splits[v] = v;
      }
      return Set.fromJS({
        values: Object.keys(splits).map((k) => splits[k])
      });
    }
  }

  Dataset.register(NativeDataset);

// =====================================================================================
// =====================================================================================

  export class RemoteDataset extends Dataset {
    static type = 'DATASET';

    static fromJS(datasetJS: DatasetJS): RemoteDataset {
      return new RemoteDataset({
        dataset: datasetJS.dataset,
        data: datasetJS.data.map(datumFromJS)
      })
    }

    public data: Datum[];

    constructor(parameters: DatasetValue) {
      super(parameters, dummyObject);
      this.data = parameters.data;
      this._ensureDataset("native");
      if (!Array.isArray(this.data)) {
        throw new TypeError("must have a `data` array")
      }
    }

    public valueOf(): DatasetValue {
      var value = super.valueOf();
      value.data = this.data;
      return value;
    }

    public toJS(): DatasetJS {
      var js = super.toJS();
      js.data = this.data.map(datumToJS);
      return js;
    }

    public equals(other: RemoteDataset): boolean {
      return super.equals(other) &&
        this.data.length === other.data.length;
      // ToDo: probably add something else here?
    }
  }

  Dataset.register(RemoteDataset);


  // ------------------------------------------
  // Scratch

  export interface Translation {
    query: () => Q.Promise<Dataset>;
    path: string[];
    name: string;
    leftOver?: Expression;
  }

  some shit so that WebStorm does not auto compile

  function makeFacetFilter(expression: Expression): any {
    if (expression.type !== 'BOOLEAN') return null;

    if (expression instanceof LiteralExpression) {
      return {
        type: String(expression.value)
      };
    } else if (expression instanceof IsExpression) {
      if (expression.lhs.isOp('ref') && expression.rhs.isOp('literal')) {
        return {
          type: 'is',
          attribute: (<RefExpression>expression.lhs).name,
          value: (<LiteralExpression>expression.rhs).value
        };
      } else {
        return null;
      }
    } else if (expression instanceof InExpression) {
      if (expression.lhs.isOp('ref') && expression.rhs.isOp('literal') && expression.rhs.type === 'SET') {
        return {
          type: 'in',
          attribute: (<RefExpression>expression.lhs).name,
          values: (<LiteralExpression>expression.rhs).value.toJS().values
        };
      } else {
        return null;
      }
    } else if (expression instanceof NotExpression) {
      var subFilter = makeFacetFilter(expression.operand);
      if (subFilter) {
        return {
          type: 'not',
          filter: subFilter
        };
      } else {
        return null;
      }
    } else if (expression instanceof AndExpression) {
      var subFilters = expression.operands.map(makeFacetFilter);
      if (subFilters.every(Boolean)) {
        return {
          type: 'and',
          filters: subFilters
        }
      } else {
        return null;
      }
    } else if (expression instanceof OrExpression) {
      var subFilters = expression.operands.map(makeFacetFilter);
      if (subFilters.every(Boolean)) {
        return {
          type: 'or',
          filters: subFilters
        };
      } else {
        return null;
      }
    }
    return null;
  }

  function makeFacetApply(expression: Expression): any {
    if (expression.type !== 'NUMBER') return null;

    if (expression instanceof LiteralExpression) {
      return {
        aggregate: 'constant',
        value: expression.value
      };
    } else if (expression instanceof AggregateExpression) {
      if (expression.fn === 'count') {
        return { aggregate: 'count' }
      }

      if (expression.attribute instanceof RefExpression) {
        return {
          aggregate: expression.fn,
          attribute: expression.attribute.name
        }
      } else {
        return null;
      }
    }
    return null;
  }

  function makeFacetSplit(expression: Expression, datasetName: string): any {
    if (expression.type !== 'DATASET') return null;

    // facet('dataName').split(ex).label('poo')
    if (expression instanceof LabelExpression) {
      var name = expression.name;
      var splitAgg = expression.operand;
      if (splitAgg instanceof AggregateExpression) {
        var datasetRef = splitAgg.operand;
        if (datasetRef instanceof RefExpression) {
          if (datasetRef.name !== datasetName) return null;
        } else {
          return null;
        }

        var attr = splitAgg.attribute;
        if (attr instanceof RefExpression) {
          return {
            name: name,
            bucket: 'identity',
            attribute: attr.name
          };
        } else if (attr instanceof NumberBucketExpression) {
          return {}; // ToDo: fill this in
        } else if (attr instanceof TimeBucketExpression) {
          return {}; // ToDo: fill this in
        }
      } else {
        return null;
      }
    } else {
      return null;
    }
  }

  function getFilter(expression: Expression): any {
    if (expression.type !== 'DATASET') return null;
    if (expression instanceof LiteralExpression) {
      return { type: 'true' };
    } else if (expression instanceof ActionsExpression) {
      var actions = expression.actions;
      if (actions.some((action) => action.action !== 'filter')) return null;
      return makeFacetFilter(actions[0].expression); // ToDo: multiple filters?
    } else {
      return null
    }
  }

  export function legacyTranslator(expression: Expression): Translation {
    if (expression instanceof ActionsExpression) {
      if (!expression.operand.isOp('literal') || expression.operand.type !== 'DATASET') {
        return null
      }
      var seenSplit = false;
      var query: any[] = [];
      var datasetName: string;
      var actions = expression.actions;
      for (var i = 0; i < actions.length; i++) {
        var action = actions[i];
        if (action instanceof DefAction) {
          if (action.expression.type !== 'DATASET') throw new Error("can not have non DATASET def actions");
          if (datasetName) throw new Error('dataset already defined');
          var filter = getFilter(action.expression);
          if (filter) {
            datasetName = action.name;
            if (filter.type !== 'true') {
              filter.operation = 'filter';
              query.push(filter);
            }
          } else {
            throw new Error('unsupported filter');
          }
        } else if (action instanceof ApplyAction) {
          if (action.expression.type === 'NUMBER') {
            var apply = makeFacetApply(action.expression);
            if (apply) {
              apply.operation = 'apply';
              apply.name = action.name;
              query.push(apply);
            } else {
              throw new Error('unsupported apply');
            }
          } else if (action.expression.type === 'DATASET') {
            if (seenSplit) throw new Error("Can have at most one split");
            legacyTranslatorSplit(action.expression, datasetName, query);
          } else {
            throw new Error("can not have non NUMBER or DATASET apply actions");
          }
        }
      }
    } else {
      return null
    }
  }

  function legacyTranslatorSplit(expression: Expression, datasetName: string, query: any[]): void {
    if (expression instanceof ActionsExpression) {
      var split = makeFacetSplit(expression.operand, datasetName);
      if (split) {
        split.operation = 'split';
        query.push(split);
      } else {
        throw new Error('unsupported split');
      }


    } else {
      throw new Error('must split on actions');
    }
  }
}
