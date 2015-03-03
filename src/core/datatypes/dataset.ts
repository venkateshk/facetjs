module Core {
  export interface AttributeInfo {
    type: string;
    datasetType?: Lookup<any>;
  }

  export interface DatasetValue {
    source: string;
    attributes?: Lookup<AttributeInfo>;

    // Native
    data?: Datum[];

    // Remote
    filter?: Expression;

    // Druid
    dataSource?: any; // ToDo: string | string[]
    timeAttribute?: string;
    forceInterval?: boolean;
    approximate?: boolean;
    context?: Lookup<any>;
  }

  export interface DatasetJS {
    source: string;
    attributes?: Lookup<AttributeInfo>;

    // Native
    data?: Datum[];

    // Remote
    filter?: ExpressionJS;

    // Druid
    dataSource?: any; // ToDo: string | string[]
    timeAttribute?: string;
    forceInterval?: boolean;
    approximate?: boolean;
    context?: Lookup<any>;
  }

  function getAttributeInfo(attributeValue: any): AttributeInfo {
    if (isDate(attributeValue)) {
      return { type: 'TIME' };
    } else if (isNumber(attributeValue)) {
      return { type: 'NUMBER' };
    } else if (isString(attributeValue)) {
      return { type: 'STRING' };
    } else if (attributeValue instanceof Dataset) {
      return {
        type: 'DATASET',
        datasetType: attributeValue.getType()
      }
    } else {
      throw new Error("Could not introspect");
    }
  }

// =====================================================================================
// =====================================================================================

  var check: ImmutableClass<DatasetValue, any>;
  export class Dataset implements ImmutableInstance<DatasetValue, any> {
    static type = 'DATASET';

    static jsToValue(parameters: any): DatasetValue {
      var value: DatasetValue = {
        source: parameters.source
      };
      var attributes = parameters.attributes;
      if (attributes) {
        if (typeof attributes !== 'object') {
          throw new TypeError("invalid attributes");
        } else {
          value.attributes = attributes;
        }
      }

      return value;
    }

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
      } else if (typeof datasetJS === 'function'){
        datasetJS = {
          source: 'remote',
          driver: datasetJS
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
    public attributes: Lookup<AttributeInfo> = null;

    constructor(parameters: DatasetValue, dummy: Dummy = null) {
      this.source = parameters.source;
      if (dummy !== dummyObject) {
        throw new TypeError("can not call `new Dataset` directly use Dataset.fromJS instead");
      }
      if (parameters.attributes) {
        this.attributes = parameters.attributes;
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
      var value: DatasetValue = {
        source: this.source
      };
      if (this.attributes) {
        value.attributes = this.attributes;
      }
      return value;
    }

    public toJS(): any {
      var js: DatasetJS = {
        source: this.source
      };
      if (this.attributes) {
        js.attributes = this.attributes;
      }
      return js;
    }

    public toString(): string {
      return "Dataset(" + this.source + ")";
    }

    public toJSON(): any {
      return this.toJS();
    }

    public equals(other: Dataset): boolean {
      return Dataset.isDataset(other) &&
        this.source === other.source;
    }

    public basis(): boolean {
      return false;
    }

    public getType(): Lookup<any> {
      var attributes = this.attributes;
      if (!attributes) throw new Error("dataset has not been introspected");
      var myType: Lookup<any> = {};
      for (var attrName in attributes) {
        if (!attributes.hasOwnProperty(attrName)) continue;
        var attrType = attributes[attrName];
        myType[attrName] = attrType.type === 'DATASET' ? attrType.datasetType : attrType.type;
      }
      return myType;
    }

    public hasRemote(): boolean {
      return false;
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

  function datumFromJS(js: Datum): Datum {
    if (typeof js !== 'object') throw new TypeError("datum must be an object");

    var datum: Datum = {};
    for (var k in js) {
      if (!js.hasOwnProperty(k)) continue;
      datum[k] = valueFromJS(js[k]);
    }

    return datum;
  }

  function datumToJS(datum: Datum): Datum {
    var js: Datum = {};
    for (var k in datum) {
      if (!datum.hasOwnProperty(k)) continue;
      if (k === '$def') continue;
      js[k] = valueToJSInlineType(datum[k]);
    }
    return js;
  }

  export class NativeDataset extends Dataset {
    static type = 'DATASET';

    static fromJS(datasetJS: any): NativeDataset {
      var value = Dataset.jsToValue(datasetJS);
      value.data = datasetJS.data.map(datumFromJS);
      return new NativeDataset(value)
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

    public toString(): string {
      return "NativeDataset(" + this.data.length + ")";
    }

    public equals(other: NativeDataset): boolean {
      return super.equals(other) &&
        this.data.length === other.data.length;
        // ToDo: probably add something else here?
    }

    public basis(): boolean {
      var data = this.data;
      return data.length === 1 && Object.keys(data[0]).length === 0;
    }

    public hasRemote(): boolean {
      if (!this.data.length) return false;
      return datumHasRemote(this.data[0]);
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
      this.attributes = null; // Since we did the change in place, blow out the attributes
      return this;
    }

    public def(name: string, exFn: Function): NativeDataset {
      // Note this works in place, fix that later if needed.
      var data = this.data;
      var n = data.length;
      for (var i = 0; i < n; i++) {
        var datum = data[i];
        datum.$def = datum.$def || {};
        datum.$def[name] = exFn(datum);
      }
      this.attributes = null; // Since we did the change in place, blow out the attributes
      return this;
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

    public group(attrFn: Function, attribute: Expression): Set {
      var splits: Lookup<any> = {};
      var data = this.data;
      var n = data.length;
      for (var i = 0; i < n; i++) {
        var datum = data[i];
        var v: any = attrFn(datum);
        splits[v] = v;
      }
      return Set.fromJS({
        setType: attribute.type,
        elements: Object.keys(splits).map((k) => splits[k])
      });
    }

    // Introspection
    public introspect(): void {
      if (this.attributes) return;

      var data = this.data;
      if (!data.length) {
        this.attributes = {};
        return;
      }
      var sample = data[0];

      var attributes: Lookup<AttributeInfo> = {};
      Object.keys(sample).forEach((attributeName) => {
        var attributeValue = sample[attributeName];
        if (attributeName === '$def') {
          Object.keys(attributeValue).forEach((attributeName) => {
            attributes[attributeName] = getAttributeInfo(attributeValue[attributeName]);
          })
        } else {
          attributes[attributeName] = getAttributeInfo(attributeValue);
        }
      });
      this.attributes = attributes;
    }

    public getType(): Lookup<any> {
      this.introspect();
      return super.getType();
    }
  }

  Dataset.register(NativeDataset);

// =====================================================================================
// =====================================================================================

  export class RemoteDataset extends Dataset {
    static type = 'DATASET';

    static jsToValue(parameters: any): DatasetValue {
      var value = Dataset.jsToValue(parameters);
      value.filter = parameters.filter || Expression.TRUE;
      return value;
    }

    public filter: Expression;

    constructor(parameters: DatasetValue, dummy: Dummy = null) {
      super(parameters, dummyObject);
      this.filter = parameters.filter;
    }

    public valueOf(): DatasetValue {
      var value = super.valueOf();
      value.filter = this.filter;
      return value;
    }

    public toJS(): DatasetJS {
      var js = super.toJS();
      if (!this.filter.equals(Expression.TRUE)) {
        js.filter = this.filter.toJS();
      }
      return js;
    }

    public toString(): string {
      return "RemoteDataset(" + this.source + ")";
    }

    public equals(other: RemoteDataset): boolean {
      return super.equals(other) &&
        this.filter.equals(other.filter);
    }

    public hasRemote(): boolean {
      return true;
    }

    public addFilter(anotherFilter: Expression): RemoteDataset {
      if (anotherFilter.type !== 'BOOLEAN') throw new Error('must be a boolean');
      var value = this.valueOf();
      value.filter = value.filter.and(anotherFilter).simplify();
      return <RemoteDataset>(new (Dataset.classMap[this.source])(value));
    }

    public generateQuery(ex: Expression): DatastoreQuery {
      throw new Error("can not call this directly");
    }
  }
}
