module Core {
  export interface SetValue {
    type: string;
    values: Lookup<any>;
  }

  export interface SetJS {
    type: string;
    values: Array<any>;
  }

  function hashFromJS(xs: Array<string>, type: string): Lookup<any> {
    var hash: Lookup<any> = {};
    for (var i = 0; i < xs.length; i++) {
      var x = valueFromJS(xs[i], type);
      hash[String(x)] = x;
    }
    return hash;
  }

  function hashToJS(hash: Lookup<any>): Array<any> {
    return Object.keys(hash).sort().map((k) => valueToJS(hash[k]));
  }

  function guessType(thing: any): string {
    var typeofThing = typeof thing;
    switch (typeofThing) {
      case 'boolean':
      case 'string':
      case 'number':
        return typeofThing.toUpperCase();

      default:
        throw new Error("Could not guess the type of the set. Please specify explicit type");
    }
  }

  var check: ImmutableClass<SetValue, SetJS>;
  export class Set implements ImmutableInstance<SetValue, SetJS> {
    static type = 'SET';

    static isSet(candidate: any): boolean {
      return isInstanceOf(candidate, Set);
    }

    static fromJS(parameters: Array<any>): Set;
    static fromJS(parameters: SetJS): Set;
    static fromJS(parameters: any): Set {
      if (Array.isArray(parameters)) {
        parameters = {
          type: guessType(parameters[0]),
          values: parameters
        }
      }
      if (typeof parameters !== "object") {
        throw new Error("unrecognizable set");
      }
      return new Set({
        type: parameters.type,
        values: hashFromJS(parameters.values, parameters.type)
      });
    }

    public type: string;
    public values: Lookup<boolean>;

    constructor(parameters: SetValue) {
      this.type = parameters.type;
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
        values: hashToJS(this.values)
      };
    }

    public toJSON(): SetJS {
      return this.toJS();
    }

    public toString(): string {
      return this.values.toString();
    }

    public equals(other: Set): boolean {
      return Set.isSet(other) &&
        this.type === other.type &&
        Object.keys(this.values).sort().join('') === Object.keys(other.values).sort().join('');
    }

    public union(other: Set): Set {
      if (this.type !== other.type) {
        throw new TypeError("can not union sets of different types");
      }

      var thisValues = this.values;
      var otherValues = other.values;
      var newValues: Lookup<any> = {};

      for (var k in thisValues) {
        if (!(thisValues.hasOwnProperty(k) && thisValues[k])) continue;
        newValues[k] = thisValues[k];
      }

      for (var k in otherValues) {
        if (!(otherValues.hasOwnProperty(k) && otherValues[k])) continue;
        newValues[k] = otherValues[k];
      }

      return new Set({
        type: this.type,
        values: newValues
      });
    }

    public intersect(other: Set): Set {
      if (this.type !== other.type) {
        throw new TypeError("can not intersect sets of different types");
      }

      var thisValues = this.values;
      var otherValues = other.values;
      var newValues: Lookup<any> = {};

      for (var k in thisValues) {
        if (!thisValues.hasOwnProperty(k)) continue;
        if (otherValues.hasOwnProperty(k)) {
          newValues[k] = thisValues[k];
        }
      }

      return new Set({
        type: this.type,
        values: newValues
      });
    }

    public test(value: any): boolean {
      return this.values.hasOwnProperty(String(value));
    }

    public add(value: any): Set {
      var values = this.values;
      var newValues: Lookup<any> = {};
      newValues[String(value)] = value;

      for (var k in values) {
        if (!values.hasOwnProperty(k)) continue;
        newValues[k] = values[k];
      }

      return new Set({
        type: this.type,
        values: newValues
      });
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
