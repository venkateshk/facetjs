module Core {
  export interface SetValue {
    values: { [k: string]: boolean }
  }

  export interface SetJS {
    values: Array<any>
  }

  function arrayToHash(a: Array<string>): { [k: string]: boolean } {
    var ret: { [k: string]: boolean } = {};
    for (var i = 0; i < a.length; i++) {
      ret[String(a[i])] = true;
    }
    return ret;
  }

  function hashToArray(a: { [k: string]: boolean }): Array<string> {
    var ret: Array<string> = [];
    for (var k in a) {
      if (a[k]) ret.push(k);
    }
    return ret.sort();
  }

  var check: ImmutableClass<SetValue, SetJS>;
  export class Set implements ImmutableInstance<SetValue, SetJS> {
    static type = 'SET';

    static isSet(candidate: any): boolean {
      return isInstanceOf(candidate, Set);
    }

    static fromJS(parameters: SetJS): Set {
      if (typeof parameters !== "object") {
        throw new Error("unrecognizable set");
      }
      return new Set({
        values: arrayToHash(parameters.values)
      });
    }

    public type: string;
    public values: Lookup<boolean>;

    constructor(parameters: SetValue) {
      this.values = parameters.values;
    }

    public valueOf(): SetValue {
      return {
        type: this.type,
        values: this.values
      };
    }

    public toJS(): SetJS {
      return {
        type: this.type,
        values: hashToArray(this.values)
      };
    }

    public toJSON(): SetJS {
      return this.toJS();
    }

    public toString(): string {
      return this.values.toString();
    }

    public equals(other: Set): boolean {
      if (!Set.isSet(other)) return false;
      var thisValues = this.toJS().values;
      var otherValues = other.toJS().values;
      var that = this;
      return otherValues.every(function(value) { return that.test(value) }) &&
        thisValues.every(function(value) { return other.test(value) });
    }

    public union(other: Set): Set {
      var ret: { [k: string]: boolean } = {};
      var othersValues = other.valueOf().values;

      for (var k in this.values) {
        if (!(this.values.hasOwnProperty(k) && this.values[k])) continue;
        ret[k] = true;
      }

      for (var k in othersValues) {
        if (!(othersValues.hasOwnProperty(k) && othersValues[k])) continue;
        ret[k] = true;
      }

      return new Set({values: ret});
    }

    public intersect(other: Set): Set {
      var ret: { [k: string]: boolean } = {};
      var othersValues = other.valueOf().values;

      for (var k in this.values) {
        if (!this.values.hasOwnProperty(k)) continue;
        if (othersValues.hasOwnProperty(k) && othersValues[k]) {
          ret[k] = true;
        }
      }

      return new Set({values: ret});
    }

    public test(value: string): boolean {
      if (this.values.hasOwnProperty(value)) return this.values[value];
      return false;
    }

    public add(value: string): Set {
      var values = this.toJS().values;
      values.push(value);
      return Set.fromJS({values: values});
    }

    public label(name: string): Dataset {
      return new NativeDataset({
        source: 'native',
        data: this.toJS().values.map((v) => {
          var datum: Datum = {};
          datum[name] = v;
          return datum
        })
      });
    }

  }
  check = Set;
}
