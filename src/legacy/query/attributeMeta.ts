module Legacy {
  function isInteger(n: any): boolean {
    return !isNaN(n) && n % 1 === 0;
  }

  function isPositiveInteger(n: any): boolean {
    return isInteger(n) && 0 < n;
  }

  function repeatString(str: string, times: number): string {
    if (times <= 0) return "";
    return new Array(times + 1).join(str);
  }


  export interface AttributeMetaJS {
    type?: string;
    separator?: string;
    rangeSize?: number;
    digitsBeforeDecimal?: number;
    digitsAfterDecimal?: number;
  }

  var check: ImmutableClass<AttributeMetaJS, AttributeMetaJS>;
  export class AttributeMeta implements ImmutableInstance<AttributeMetaJS, AttributeMetaJS> {
    static DEFAULT: DefaultAttributeMeta;
    static UNIQUE: UniqueAttributeMeta;
    static HISTOGRAM: HistogramAttributeMeta;

    static isAttributeMeta(candidate: any): boolean {
      return isInstanceOf(candidate, AttributeMeta);
    }

    static classMap: any;

    static fromJS(parameters: AttributeMetaJS): AttributeMeta {
      if (parameters.type === "range" && !hasOwnProperty(parameters, 'rangeSize')) {
        parameters.rangeSize = (<any>parameters).size; // Back compatibility
      }

      if (typeof parameters !== "object") {
        throw new Error("unrecognizable attributeMeta");
      }
      if (!hasOwnProperty(parameters, "type")) {
        throw new Error("type must be defined");
      }
      if (typeof parameters.type !== "string") {
        throw new Error("type must be a string");
      }
      var Class = AttributeMeta.classMap[parameters.type];
      if (!Class) {
        throw new Error("unsupported attributeMeta type '" + parameters.type + "'");
      }
      return Class.fromJS(parameters);
    }

    public type: string;

    constructor(parameters: AttributeMetaJS, dummy: Dummy = null) {
      this.type = parameters.type;
      if (dummy !== dummyObject) {
        throw new TypeError("can not call `new AttributeMeta` directly use AttributeMeta.fromJS instead");
      }
    }

    public _ensureType(attributeMetaType: string) {
      if (!this.type) {
        this.type = attributeMetaType;
        return;
      }
      if (this.type !== attributeMetaType) {
        throw new TypeError("incorrect attributeMeta `type` '" + this.type + "' (needs to be: '" + attributeMetaType + "')");
      }
    }

    public toString(): string {
      return 'Meta(' + this.type + ')';
    }

    public valueOf(): AttributeMetaJS {
      return {
        type: this.type
      };
    }

    public toJS(): AttributeMetaJS {
      return this.valueOf();
    }

    public toJSON(): AttributeMetaJS {
      return this.valueOf();
    }

    public equals(other: AttributeMeta): boolean {
      return AttributeMeta.isAttributeMeta(other) &&
        this.type === other.type;
    }

    public serialize(value: any): string {
      return value;
    }
  }
  check = AttributeMeta;

  export class DefaultAttributeMeta extends AttributeMeta {
    static fromJS(parameters: AttributeMetaJS): DefaultAttributeMeta {
      return new DefaultAttributeMeta(parameters);
    }

    constructor(parameters = {}) {
      super(parameters, dummyObject);
      this._ensureType("default");
    }
  }

  export class LargeAttributeMeta extends AttributeMeta {
    static fromJS(parameters: AttributeMetaJS): LargeAttributeMeta {
      return new LargeAttributeMeta(parameters);
    }

    constructor(parameters = {}) {
      super(parameters, dummyObject);
      this._ensureType("large");
    }
  }

  export class RangeAttributeMeta extends AttributeMeta {
    static fromJS(parameters: AttributeMetaJS): RangeAttributeMeta {
      return new RangeAttributeMeta(parameters);
    }

    public separator: string;
    public rangeSize: number;
    public digitsBeforeDecimal: number;
    public digitsAfterDecimal: number;

    constructor(parameters: AttributeMetaJS) {
      super(parameters, dummyObject);
      this.separator = parameters.separator;
      this.rangeSize = parameters.rangeSize;
      this.digitsBeforeDecimal = parameters.digitsBeforeDecimal;
      this.digitsAfterDecimal = parameters.digitsAfterDecimal;
      this._ensureType("range");
      this.separator || (this.separator = ";");
      if (!(typeof this.separator === "string" && this.separator.length)) {
        throw new TypeError("`separator` must be a non-empty string");
      }
      if (typeof this.rangeSize !== "number") {
        throw new TypeError("`rangeSize` must be a number");
      }
      if (this.rangeSize > 1) {
        if (!isInteger(this.rangeSize)) {
          throw new Error("`rangeSize` greater than 1 must be an integer");
        }
      } else {
        if (!isInteger(1 / this.rangeSize)) {
          throw new Error("`rangeSize` less than 1 must divide 1");
        }
      }

      if (this.digitsBeforeDecimal != null) {
        if (!isPositiveInteger(this.digitsBeforeDecimal)) {
          throw new Error("`digitsBeforeDecimal` must be a positive integer");
        }
      } else {
        this.digitsBeforeDecimal = null;
      }

      if (this.digitsAfterDecimal != null) {
        if (!isPositiveInteger(this.digitsAfterDecimal)) {
          throw new Error("`digitsAfterDecimal` must be a positive integer");
        }
        var digitsInSize = (String(this.rangeSize).split(".")[1] || "").length;
        if (this.digitsAfterDecimal < digitsInSize) {
          throw new Error("`digitsAfterDecimal` must be at least " + digitsInSize + " to accommodate for a `rangeSize` of " + this.rangeSize);
        }
      } else {
        this.digitsAfterDecimal = null;
      }
    }

    public valueOf() {
      var attributeMetaSpec = super.valueOf();
      if (this.separator !== ";") {
        attributeMetaSpec.separator = this.separator;
      }
      attributeMetaSpec.rangeSize = this.rangeSize;
      if (this.digitsBeforeDecimal !== null) {
        attributeMetaSpec.digitsBeforeDecimal = this.digitsBeforeDecimal;
      }
      if (this.digitsAfterDecimal !== null) {
        attributeMetaSpec.digitsAfterDecimal = this.digitsAfterDecimal;
      }
      return attributeMetaSpec;
    }

    public equals(other: AttributeMeta): boolean {
      return super.equals(other) &&
        this.separator === (<RangeAttributeMeta>other).separator &&
        this.rangeSize === (<RangeAttributeMeta>other).rangeSize &&
        this.digitsBeforeDecimal === (<RangeAttributeMeta>other).digitsBeforeDecimal &&
        this.digitsAfterDecimal === (<RangeAttributeMeta>other).digitsAfterDecimal;
    }

    public _serializeNumber(value: number): string {
      if (value === null) return "";
      var valueStr = String(value);
      if (this.digitsBeforeDecimal === null && this.digitsAfterDecimal === null) {
        return valueStr;
      }
      var valueStrSplit = valueStr.split(".");
      var before = valueStrSplit[0];
      var after = valueStrSplit[1];
      if (this.digitsBeforeDecimal) {
        before = repeatString("0", this.digitsBeforeDecimal - before.length) + before;
      }

      if (this.digitsAfterDecimal) {
        after || (after = "");
        after += repeatString("0", this.digitsAfterDecimal - after.length);
      }

      valueStr = before;
      if (after) valueStr += "." + after;
      return valueStr;
    }

    public serialize(range: any): string {
      if (!(Array.isArray(range) && range.length === 2)) return null;
      return this._serializeNumber(range[0]) + this.separator + this._serializeNumber(range[1]);
    }

    public getMatchingRegExpString() {
      var separatorRegExp = this.separator.replace(/[.$^{[(|)*+?\\]/g, (c) => "\\" + c);
      var beforeRegExp = this.digitsBeforeDecimal ? "-?\\d{" + this.digitsBeforeDecimal + "}" : "(?:-?[1-9]\\d*|0)";
      var afterRegExp = this.digitsAfterDecimal ? "\\.\\d{" + this.digitsAfterDecimal + "}" : "(?:\\.\\d*[1-9])?";
      var numberRegExp = beforeRegExp + afterRegExp;
      return "/^(" + numberRegExp + ")" + separatorRegExp + "(" + numberRegExp + ")$/";
    }
  }

  export class UniqueAttributeMeta extends AttributeMeta {
    static fromJS(parameters: AttributeMetaJS): UniqueAttributeMeta {
      return new UniqueAttributeMeta(parameters);
    }

    constructor(parameters = {}) {
      super(parameters, dummyObject);
      this._ensureType("unique");
    }

    public serialize(value: any): string {
      throw new Error("can not serialize an approximate unique value");
    }
  }

  export class HistogramAttributeMeta extends AttributeMeta {
    static fromJS(parameters: AttributeMetaJS): HistogramAttributeMeta {
      return new HistogramAttributeMeta(parameters);
    }

    constructor(parameters = {}) {
      super(parameters, dummyObject);
      this._ensureType("histogram");
    }

    public serialize(value: any): string {
      throw new Error("can not serialize a histogram value");
    }
  }

  AttributeMeta.classMap = {
    "default": DefaultAttributeMeta,
    large: LargeAttributeMeta,
    range: RangeAttributeMeta,
    unique: UniqueAttributeMeta,
    histogram: HistogramAttributeMeta
  };

  AttributeMeta.DEFAULT = new DefaultAttributeMeta();
  AttributeMeta.UNIQUE = new UniqueAttributeMeta();
  AttributeMeta.HISTOGRAM = new HistogramAttributeMeta();
}
