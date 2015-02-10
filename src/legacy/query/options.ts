module Legacy {
  export interface FacetOptionsJS {
    [optionName: string]: any // string | number
  }

  var check: ImmutableClass<FacetOptionsJS, FacetOptionsJS>;
  export class FacetOptions implements ImmutableInstance<FacetOptionsJS, FacetOptionsJS> {
    static isFacetOptions(candidate: FacetOptions) {
      return isInstanceOf(candidate, FacetOptions);
    }

    static fromJS(options: FacetOptionsJS) {
      return new FacetOptions(options);
    }

  [option: string]: any;

    constructor(options: FacetOptionsJS) {
      for (var k in options) {
        if (!options.hasOwnProperty(k)) continue;
        var v = options[k];
        var typeofV = typeof(v);
        if (typeofV !== "string" && typeofV !== "number") {
          throw new TypeError("bad option value type (key: " + k + ")");
        }
        this[k] = v;
      }
    }

    public toString(): string {
      var parts: string[] = [];
      for (var k in this) {
        if (!this.hasOwnProperty(k)) continue;
        parts.push(k + ":" + this[k]);
      }
      return "[" + (parts.sort().join("; ")) + "]";
    }

    public valueOf(): FacetOptionsJS {
      var value: FacetOptionsJS = {};
      for (var k in this) {
        if (!this.hasOwnProperty(k)) continue;
        value[k] = this[k];
      }
      return value;
    }

    public toJS(): FacetOptionsJS {
      return this.valueOf();
    }

    public toJSON(): FacetOptionsJS {
      return this.valueOf();
    }

    public equals(other: FacetOptions) {
      return FacetOptions.isFacetOptions(other) &&
        this.toString() === other.toString();
    }
  }
  check = FacetOptions;
}
