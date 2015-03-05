module Core {
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

  function datumFromJS(js: Datum): Datum {
    if (typeof js !== 'object') throw new TypeError("datum must be an object");

    var datum: Datum = Object.create(null);
    for (var k in js) {
      if (!hasOwnProperty(js, k)) continue;
      datum[k] = valueFromJS(js[k]);
    }

    return datum;
  }

  function datumToJS(datum: Datum): Datum {
    var js: Datum = {};
    for (var k in datum) {
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
        datum.$def = datum.$def || Object.create(null);
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
      var datum = data[0];

      var attributes: Lookup<AttributeInfo> = {};
      Object.keys(datum).forEach((applyName) => {
        var applyValue = datum[applyName];
        if (applyName !== '$def') {
          attributes[applyName] = getAttributeInfo(applyValue);
        } else {
          Object.keys(applyValue).forEach((defName) => {
            var defValue = applyValue[defName];
            attributes[defName] = getAttributeInfo(defValue);
          })
        }
      });
      this.attributes = attributes;
    }

    public getType(): Lookup<any> {
      this.introspect();
      return super.getType();
    }

    public getRemoteDatasets(): RemoteDataset[] {
      if (this.data.length === 0) return [];
      var datum = this.data[0];
      var remoteDatasets: RemoteDataset[][] = [];
      Object.keys(datum).forEach((applyName) => {
        var applyValue = datum[applyName];
        if (applyName !== '$def') {
          if (applyValue instanceof Dataset) {
            remoteDatasets.push(applyValue.getRemoteDatasets());
          }
        } else {
          Object.keys(applyValue).forEach((defName) => {
            var defValue = applyValue[defName];
            if (defValue instanceof Dataset) {
              remoteDatasets.push(defValue.getRemoteDatasets());
            }
          })
        }
      });
      return mergeRemoteDatasets(remoteDatasets);
    }
  }

  Dataset.register(NativeDataset);
}
