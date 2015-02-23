module Core {
  export interface DatasetValue {
    source: string;
    data?: Datum[];
  }

// =====================================================================================
// =====================================================================================

  var check: ImmutableClass<DatasetValue, any>;
  export class Dataset implements ImmutableInstance<DatasetValue, any> {
    static type = 'DATASET';

    static isDataset(candidate: any): boolean {
      return isInstanceOf(candidate, Dataset);
    }

    static classMap: Lookup<typeof Dataset> = {};

    static register(ex: typeof Dataset): void {
      var op = (<any>ex).name.replace('Dataset', '').replace(/^\w/, (s: string) => s.toLowerCase());
      Dataset.classMap[op] = ex;
    }

    static fromJS(datasetJS: any): Dataset {
      if (Array.isArray(datasetJS)) {
        datasetJS = {
          source: 'native',
          data: datasetJS
        }
      }
      if (!datasetJS.hasOwnProperty("source")) {
        throw new Error("dataset `source` must be defined");
      }
      var source: string = datasetJS.source;
      if (typeof source !== "string") {
        throw new Error("dataset must be a string");
      }
      var ClassFn = Dataset.classMap[source];
      if (!ClassFn) {
        throw new Error("unsupported dataset '" + source + "'");
      }

      return ClassFn.fromJS(datasetJS);
    }

    public source: string;

    constructor(parameters: DatasetValue, dummy: Dummy = null) {
      this.source = parameters.source;
      if (dummy !== dummyObject) {
        throw new TypeError("can not call `new Dataset` directly use Dataset.fromJS instead");
      }
    }

    protected _ensureSource(source: string) {
      if (!this.source) {
        this.source = source;
        return;
      }
      if (this.source !== source) {
        throw new TypeError("incorrect dataset '" + this.source + "' (needs to be: '" + source + "')");
      }
    }

    public valueOf(): DatasetValue {
      return {
        source: this.source
      };
    }

    public toJS(): any {
      return {
        source: this.source
      };
    }

    public toString(): string {
      return "<Dataset:" + this.source + ">";
    }

    public toJSON(): any {
      return this.toJS();
    }

    public equals(other: Dataset): boolean {
      return Dataset.isDataset(other) &&
        this.source === other.source;
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

  function isDate(dt: any) {
    return Boolean(dt.toISOString)
  }

  function isNumber(n: any) {
    return !isNaN(Number(n));
  }

  function isString(str: string) {
    return typeof str === "string";
  }

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
            v = { type: 'TIME', value: v };
          } else {
            var type = v.constructor.type;
            v = v.toJS();
            if (!Array.isArray(v)) {
              v.type = type;
            }
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
          source: 'native',
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

          case 'TIME':
            v = new Date(v.value);
            break;

          case 'TIME_RANGE':
            v = TimeRange.fromJS(v);
            break;

          case 'SHAPE':
            v = Shape.fromJS(v);
            break;

          case 'SET':
            v = Set.fromJS(v);
            break;

          default:
            if (!v.toISOString) { // Allow native date
              throw new Error('can not have an object without a `type` as a datum value')
            }
        }
      }
      datum[k] = v;
    }

    return datum;
  }

  export class NativeDataset extends Dataset {
    static type = 'DATASET';

    static fromJS(datasetJS: any): NativeDataset {
      return new NativeDataset({
        source: datasetJS.source,
        data: datasetJS.data.map(datumFromJS)
      })
    }

    public data: Datum[];

    constructor(parameters: DatasetValue) {
      super(parameters, dummyObject);
      this.data = parameters.data;
      this._ensureSource("native");
      if (!Array.isArray(this.data)) {
        throw new TypeError("must have a `data` array")
      }
    }

    public valueOf(): DatasetValue {
      var value = super.valueOf();
      value.data = this.data;
      return value;
    }

    public toJS(): any {
      return this.data.map(datumToJS);
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
        source: 'native',
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
        source: 'native',
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

    // Introspection
    public introspect(): Lookup<any> {
      var data = this.data;
      if (!data.length) return null;
      var sample = data[0];

      var attributeTypes: Lookup<any> = {};
      Object.keys(sample).forEach((attributeName) => {
        var attributeValue = sample[attributeName];
        var type: string = null;
        if (isDate(attributeValue)) {
          type = 'TIME';
        } else if (isNumber(attributeValue)) {
          type = 'NUMBER';
        } else if (isString(attributeValue)) {
          type = 'STRING';
        } else if (attributeValue instanceof Dataset) {
          type = attributeValue.introspect();
        }

        attributeTypes[attributeName] = type;
      });
      return attributeTypes;
    }
  }

  Dataset.register(NativeDataset);

// =====================================================================================
// =====================================================================================

  export class RemoteDataset extends Dataset {
    static type = 'DATASET';

    static fromJS(datasetJS: any): RemoteDataset {
      return new RemoteDataset({
        source: datasetJS.source,
        data: datasetJS.data.map(datumFromJS)
      })
    }

    public data: Datum[];

    constructor(parameters: DatasetValue) {
      super(parameters, dummyObject);
      this.data = parameters.data;
      this._ensureSource("native");
      if (!Array.isArray(this.data)) {
        throw new TypeError("must have a `data` array")
      }
    }

    public valueOf(): DatasetValue {
      var value = super.valueOf();
      value.data = this.data;
      return value;
    }

    public toJS(): any {
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
}
