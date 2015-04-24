module Facet {
  export interface ComputeFn {
    (d: Datum, def?: boolean): any;
  }

  export interface ComputePromiseFn {
    (d: Datum): Q.Promise<any>;
  }

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

  export interface Column {
    name: string;
    type: string;
    columns?: OrderedColumns;
  }

  export type OrderedColumns = Column[];

  var typeOrder: Lookup<number> = {
    'TIME': 1,
    'TIME_RANGE': 2,
    'SET/TIME': 3,
    'SET/TIME_RANGE': 4,
    'STRING': 5,
    'SET/STRING': 6,
    'NUMBER': 7,
    'NUMBER_RANGE': 8,
    'SET/NUMBER': 9,
    'SET/NUMBER_RANGE': 10,
    'DATASET': 11
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
      return new AttributeInfo({ type: 'TIME' });
    } else if (isNumber(attributeValue)) {
      return new AttributeInfo({ type: 'NUMBER' });
    } else if (isString(attributeValue)) {
      return new AttributeInfo({ type: 'STRING' });
    } else if (attributeValue instanceof Dataset) {
      return new AttributeInfo(attributeValue.getFullType())
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

  function joinDatums(datumA: Datum, datumB: Datum): Datum {
    var newDatum: Datum = Object.create(null);
    for (var k in datumA) {
      newDatum[k] = datumA[k];
    }
    for (var k in datumB) {
      newDatum[k] = datumB[k];
    }
    if (datumA.$def && datumB.$def) {
      newDatum.$def = joinDatums(datumA.$def, datumB.$def);
    }
    return newDatum;
  }

  function copy(obj: Lookup<any>): Lookup<any> {
    var newObj: Lookup<any> = {};
    var k: string;
    for (k in obj) {
      if (hasOwnProperty(obj, k)) newObj[k] = obj[k];
    }
    return newObj;
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
    public apply(name: string, exFn: ComputeFn): NativeDataset {
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

    public applyPromise(name: string, exFn: ComputePromiseFn): Q.Promise<NativeDataset> {
      // Note this works in place, fix that later if needed.
      var ds = this;
      var promises = this.data.map(exFn);
      return Q.all(promises).then((values) => {
        var data = ds.data;
        var n = data.length;
        for (var i = 0; i < n; i++) data[i][name] = values[i];
        this.attributes = null; // Since we did the change in place, blow out the attributes
        return ds;
      });
    }

    public def(name: string, exFn: ComputeFn): NativeDataset {
      // Note this works in place, fix that later if needed.
      var data = this.data;
      var n = data.length;
      for (var i = 0; i < n; i++) {
        var datum = data[i];
        datum.$def = datum.$def || Object.create(null);
        datum.$def[name] = exFn(datum, true);
      }
      this.attributes = null; // Since we did the change in place, blow out the attributes
      return this;
    }

    public filter(exFn: ComputeFn): NativeDataset {
      return new NativeDataset({
        source: 'native',
        data: this.data.filter((datum) => exFn(datum))
      })
    }

    public sort(exFn: ComputeFn, direction: string): NativeDataset {
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

    public sum(attrFn: ComputeFn): number {
      var sum = 0;
      var data = this.data;
      var n = data.length;
      for (var i = 0; i < n; i++) {
        sum += attrFn(data[i])
      }
      return sum;
    }

    public min(attrFn: ComputeFn): number {
      var min = Infinity;
      var data = this.data;
      var n = data.length;
      for (var i = 0; i < n; i++) {
        var v = attrFn(data[i]);
        if (v < min) min = v;
      }
      return min;
    }

    public max(attrFn: ComputeFn): number {
      var max = Infinity;
      var data = this.data;
      var n = data.length;
      for (var i = 0; i < n; i++) {
        var v = attrFn(data[i]);
        if (max < v) max = v;
      }
      return max;
    }

    public group(attrFn: ComputeFn, attribute: Expression): Set {
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

    public getFullType(): FullType {
      this.introspect();
      return super.getFullType();
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

    public getRemoteDatasetIds(): string[] {
      if (this.data.length === 0) return [];
      var datum = this.data[0];
      var push = Array.prototype.push;
      var remoteDatasetIds: string[] = [];
      Object.keys(datum).forEach((applyName) => {
        var applyValue = datum[applyName];
        if (applyName !== '$def') {
          if (applyValue instanceof Dataset) {
            push.apply(remoteDatasetIds, applyValue.getRemoteDatasets());
          }
        } else {
          Object.keys(applyValue).forEach((defName) => {
            var defValue = applyValue[defName];
            if (defValue instanceof Dataset) {
              push.apply(remoteDatasetIds, defValue.getRemoteDatasets());
            }
          })
        }
      });
      return deduplicateSort(remoteDatasetIds);
    }

    public join(other: NativeDataset): NativeDataset {
      var thisKey = this.key;
      var otherKey = other.key;

      var thisData = this.data;
      var otherData = other.data;
      var datum: Datum;
      var k: string;

      var mapping: Lookup<Datum[]> = Object.create(null);
      for (var i = 0; i < thisData.length; i++) {
        datum = thisData[i];
        k = String(thisKey ? datum[thisKey] : i);
        mapping[k] = [datum];
      }
      for (var i = 0; i < otherData.length; i++) {
        datum = otherData[i];
        k = String(otherKey ? datum[otherKey] : i);
        if (!mapping[k]) mapping[k] = [];
        mapping[k].push(datum);
      }

      var newData: Datum[] = [];
      for (var j in mapping) {
        var datums = mapping[j];
        if (datums.length === 1) {
          newData.push(datums[0]);
        } else {
          newData.push(joinDatums(datums[0], datums[1]));
        }
      }
      return new NativeDataset({ source: 'native', data: newData });
    }

    public getOrderedColumns(): OrderedColumns {
      this.introspect();
      var orderedColumns: OrderedColumns = [];
      var attributes = this.attributes;

      var subDatasetAdded: boolean = false;
      for (var attributeName in attributes) {
        if (!hasOwnProperty(attributes, attributeName)) continue;
        var attributeInfo = attributes[attributeName];
        var column: Column = {
          name: attributeName,
          type: attributeInfo.type
        };
        if (attributeInfo.type === 'DATASET') {
          if (!subDatasetAdded) {
            subDatasetAdded = true;
            column.columns = this.data[0][attributeName].getOrderedColumns();
            orderedColumns.push(column);
          }
        } else {
          orderedColumns.push(column);
        }
      }

      return orderedColumns.sort((a, b) => {
        var typeDiff = typeOrder[a.type] - typeOrder[b.type];
        if (typeDiff) return typeDiff;
        return a.name.localeCompare(b.name);
      });
    }

    public _flattenHelper(flattenedColumns: OrderedColumns, prefix: string, context: Datum, flat: Datum[]): void {
      var data = this.data;
      for (var i = 0; i < data.length; i++) {
        var datum = data[i];
        var flatDatum = copy(context);
        for (var j = 0; j < flattenedColumns.length; j++) {
          var flattenedColumn = flattenedColumns[j];
          if (flattenedColumn.type === 'DATASET') {
            datum[flattenedColumn.name]._flattenHelper(
              flattenedColumn.columns,
              prefix + flattenedColumn.name + '.',
              flatDatum,
              flat
            );
          } else {
            flatDatum[prefix + flattenedColumn.name] = datum[flattenedColumn.name];
          }
        }
        if (flattenedColumns[flattenedColumns.length - 1].type !== 'DATASET') {
          // There is no subset to delegate to
          flat.push(flatDatum);
        }
      }
    }

    public flatten(): Datum[] {
      var flattenedColumns = this.getOrderedColumns();
      var flat: Datum[] = [];
      this._flattenHelper(flattenedColumns, '', {}, flat);
      return flat;
    }
  }

  Dataset.register(NativeDataset);
}
