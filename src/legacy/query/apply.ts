module Legacy {
  var DEFAULT_DATASET = "main";

  export interface FacetApplyJS {
    operation?: string
    name?: string;
    aggregate?: string;
    arithmetic?: string;
    dataset?: string;
    attribute?: string;
    value?: number;
    quantile?: number;
    operands?: FacetApplyJS[];
    filter?: FacetFilterJS;
    options?: FacetOptionsJS;
  }

  export interface FacetApplyValue {
    name?: string;
    aggregate?: string;
    arithmetic?: string;
    dataset?: string;
    attribute?: string;
    value?: number;
    quantile?: number;
    operands?: FacetApply[];
    filter?: FacetFilter;
    options?: FacetOptions;
  }

  function convertToValue(js: FacetApplyJS, datasetContext: string): FacetApplyValue {
    var value: FacetApplyValue = {
      name: js.name,
      aggregate: js.aggregate,
      arithmetic: js.arithmetic,
      dataset: js.dataset,
      attribute: js.attribute,
      value: js.value,
      quantile: js.quantile
    };
    if (datasetContext === DEFAULT_DATASET && js.dataset) datasetContext = js.dataset;
    if (js.operands) value.operands = js.operands.map((operand) => FacetApply.fromJS(operand, datasetContext));
    if (js.filter) value.filter = FacetFilter.fromJS(js.filter);
    if (js.options) value.options = FacetOptions.fromJS(js.options);
    return value;
  }

  var check: ImmutableClass<FacetApplyValue, FacetApplyJS>;
  export class FacetApply implements ImmutableInstance<FacetApplyValue, FacetApplyJS> {
    static isFacetApply(candidate: any): boolean {
      return isInstanceOf(candidate, FacetApply);
    }

    static parse(str: string): FacetApply {
      return FacetApply.fromJS(applyParser.parse(str));
    }

    static aggregateClassMap: any;
    static arithmeticClassMap: any;

    static fromJS(parameters: FacetApplyJS, datasetContext: string = DEFAULT_DATASET): FacetApply {
      if (typeof parameters !== "object") throw new Error("unrecognizable apply");
      var ApplyConstructor: any;
      if (parameters.hasOwnProperty("aggregate")) {
        if (typeof parameters.aggregate !== "string") {
          throw new Error("aggregate must be a string");
        }
        ApplyConstructor = FacetApply.aggregateClassMap[parameters.aggregate];
        if (!ApplyConstructor) {
          throw new Error("unsupported aggregate '" + parameters.aggregate + "'");
        }
      } else if (parameters.hasOwnProperty("arithmetic")) {
        if (typeof parameters.arithmetic !== "string") {
          throw new Error("arithmetic must be a string");
        }
        ApplyConstructor = FacetApply.arithmeticClassMap[parameters.arithmetic];
        if (!ApplyConstructor) {
          throw new Error("unsupported arithmetic '" + parameters.arithmetic + "'");
        }
      } else {
        throw new Error("must have an aggregate or arithmetic");
      }
      return ApplyConstructor.fromJS(parameters, datasetContext);
    }

    public name: string;
    public operands: FacetApply[];
    public dataset: string;
    public datasets: string[];
    public aggregate: string;
    public arithmetic: string;
    public attribute: string;
    public filter: FacetFilter;
    public options: FacetOptions;

    constructor(parameters: FacetApplyValue, datasetContext: string = DEFAULT_DATASET, dummy: Dummy = null) {
      if (parameters.name) this.name = parameters.name;
      if (parameters.aggregate) this.aggregate = parameters.aggregate;
      if (parameters.arithmetic) this.arithmetic = parameters.arithmetic;
      if (parameters.attribute) this.attribute = parameters.attribute;
      if (parameters.options) this.options = parameters.options;

      if (dummy !== dummyObject) {
        throw new TypeError("can not call `new FacetApply` directly use FacetApply.fromJS instead");
      }

      var dataset = parameters.dataset;
      var operands = parameters.operands;
      if (operands) {
        if (!(Array.isArray(operands) && operands.length === 2)) {
          throw new TypeError("operands must be an array of length 2");
        }
        this.operands = operands;
        var seenDataset: any = {};
        operands.forEach((operand) => {
          operand.getDatasets().forEach((ds) => {
            seenDataset[ds] = 1;
          });
        });
        var datasets = Object.keys(seenDataset).sort();
        if (dataset && dataset !== DEFAULT_DATASET) {
          if (datasets.length > 1 || (datasets[0] !== dataset && datasets[0] !== DEFAULT_DATASET)) {
            var otherDatasets = datasets.filter((d) => d !== dataset);
            throw new Error("dataset conflict between '" + dataset + "' and '" + otherDatasets.join(', ') + "'");
          }
          this.dataset = dataset;
        } else if (datasets.length === 1) {
          this.dataset = datasets[0];
        }
        this.datasets = datasets;
      } else {
        this.dataset = dataset || datasetContext;
      }
    }

    public _ensureAggregate(aggregate: string): void {
      if (!this.aggregate) {
        this.aggregate = aggregate;
        return;
      }
      if (this.aggregate !== aggregate) {
        throw new TypeError("incorrect apply aggregate '" + this.aggregate + "' (needs to be: '" + aggregate + "')");
      }
    }

    public _ensureArithmetic(arithmetic: string): void {
      if (!this.arithmetic) {
        this.arithmetic = arithmetic;
        return;
      }
      if (this.arithmetic !== arithmetic) {
        throw new TypeError("incorrect apply arithmetic '" + this.arithmetic + "' (needs to be: '" + arithmetic + "')");
      }
    }

    public _verifyName(): void {
      if (!this.name) {
        return;
      }
      if (typeof this.name !== "string") {
        throw new TypeError("apply name must be a string");
      }
    }

    public _verifyAttribute(): void {
      if (typeof this.attribute !== "string") {
        throw new TypeError("attribute must be a string");
      }
    }

    public _addNameToString(str: string): string {
      if (!this.name) return str;
      return this.name + " <- " + str;
    }

    public _datasetOrNothing(): string {
      if (this.dataset === DEFAULT_DATASET) {
        return "";
      } else {
        return this.dataset;
      }
    }

    public _datasetWithAttribute(): string {
      if (this.dataset === DEFAULT_DATASET) {
        return this.attribute;
      } else {
        return this.dataset + "@" + this.attribute;
      }
    }

    public toString(from: string) {
      return this._addNameToString("base apply");
    }

    public toHash(): string {
      throw new Error("can not call FacetApply.toHash directly");
    }

    public valueOf(): FacetApplyValue {
      var applySpec: FacetApplyValue = {};
      if (this.name) {
        applySpec.name = this.name;
      }
      if (this.filter) {
        applySpec.filter = this.filter;
      }
      if (this.options) {
        applySpec.options = this.options;
      }
      if (this.arithmetic) {
        applySpec.arithmetic = this.arithmetic;
        var myDataset = this.dataset;
        applySpec.operands = this.operands;
        if (myDataset) {
          applySpec.dataset = myDataset;
        }
      } else {
        applySpec.aggregate = this.aggregate;
        if (this.attribute) {
          applySpec.attribute = this.attribute;
        }
        if (this.dataset) {
          applySpec.dataset = this.dataset;
        }
      }
      return applySpec;
    }

    public toJS(datasetContext: string = DEFAULT_DATASET): FacetApplyJS {
      var applySpec: FacetApplyJS = {};
      if (this.name) {
        applySpec.name = this.name;
      }
      if (this.filter) {
        applySpec.filter = this.filter.toJS();
      }
      if (this.options) {
        applySpec.options = this.options.toJS();
      }
      if (this.arithmetic) {
        applySpec.arithmetic = this.arithmetic;
        var myDataset = this.dataset;
        applySpec.operands = this.operands.map((operand) => operand.toJS(myDataset));
        if (myDataset && myDataset !== datasetContext) {
          applySpec.dataset = myDataset;
        }
      } else {
        applySpec.aggregate = this.aggregate;
        if (this.attribute) {
          applySpec.attribute = this.attribute;
        }
        if (this.dataset && this.dataset !== datasetContext) {
          applySpec.dataset = this.dataset;
        }
      }
      return applySpec;
    }

    public toJSON(): FacetApplyJS {
      return this.toJS();
    }

    public equals(other: FacetApply): boolean {
      if (!FacetApply.isFacetApply(other)) return false;
      if (this.operands) {
        return this.arithmetic === other.arithmetic &&
          this.operands.every((op, i) => op.equals(other.operands[i]));
      } else {
        return this.aggregate === other.aggregate &&
          this.attribute === other.attribute &&
          this.dataset === other.dataset &&
          Boolean(this.filter) === Boolean(other.filter) &&
          (!this.filter || this.filter.equals(other.filter)) &&
          Boolean(this.options) === Boolean(other.options) &&
          (!this.options || this.options.equals(other.options));
      }
    }

    public isAdditive(): boolean {
      return false;
    }

    public addName(name: string): FacetApply {
      var applySpec = this.toJS();
      applySpec.name = name;
      return FacetApply.fromJS(applySpec);
    }

    public getDataset(): string {
      if (this.operands) {
        return this.datasets[0];
      } else {
        return this.dataset;
      }
    }

    public getDatasets(): string[] {
      if (this.operands) {
        return this.datasets;
      } else {
        return [this.dataset];
      }
    }

    public getAttributes(): string[] {
      var attributeCollection: any = {};
      this._collectAttributes(attributeCollection);
      return Object.keys(attributeCollection).sort();
    }

    public _collectAttributes(attributes: any): void {
      if (this.operands) {
        this.operands[0]._collectAttributes(attributes);
        this.operands[1]._collectAttributes(attributes);
      } else {
        if (this.attribute) {
          attributes[this.attribute] = 1;
        }
      }
    }
  }
  check = FacetApply;

  export class ConstantApply extends FacetApply {
    static fromJS(parameters: FacetApplyJS, datasetContext: string = DEFAULT_DATASET): ConstantApply {
      return new ConstantApply(convertToValue(parameters, datasetContext), datasetContext);
    }

    public value: number;

    constructor(parameters: number, datasetContext?: string);
    constructor(parameters: FacetApplyValue, datasetContext?: string);
    constructor(parameters: any, datasetContext: string = DEFAULT_DATASET) {
      if (typeof parameters === 'number') parameters = {value: parameters};
      super(parameters, datasetContext, dummyObject);
      var value = parameters.value;
      this.dataset = null;
      this._ensureAggregate("constant");
      this._verifyName();
      if (typeof value === "string") {
        value = Number(value);
      }
      if (typeof value !== "number" || isNaN(value)) {
        throw new Error("constant apply must have a numeric value");
      }
      this.value = value;
    }

    public toString(): string {
      return this._addNameToString(String(this.value));
    }

    public toHash(): string {
      var hashStr = "C:" + this.value;
      if (this.filter) {
        hashStr += "/" + this.filter.toHash();
      }
      return hashStr;
    }

    public valueOf(): FacetApplyValue {
      var apply = super.valueOf();
      apply.value = this.value;
      return apply;
    }

    public toJS(): FacetApplyJS {
      var apply = super.toJS();
      apply.value = this.value;
      return apply;
    }

    public equals(other: FacetApply): boolean {
      return super.equals(other) &&
        this.value === (<ConstantApply>other).value;
    }

    public isAdditive(): boolean {
      return true;
    }

    public getDatasets(): string[] {
      return [];
    }
  }

  export class CountApply extends FacetApply {
    static fromJS(parameters: FacetApplyJS, datasetContext: string = DEFAULT_DATASET): CountApply {
      return new CountApply(convertToValue(parameters, datasetContext), datasetContext);
    }

    constructor(parameters: FacetApplyValue = {}, datasetContext: string = DEFAULT_DATASET) {
      super(parameters, datasetContext, dummyObject);
      var filter = parameters.filter;

      if (filter) {
        this.filter = FacetFilter.fromJS(filter);
      }
      this._ensureAggregate("count");
      this._verifyName();
    }

    public toString(): string {
      return this._addNameToString("count()");
    }

    public toHash(): string {
      var hashStr = "CT" + (this._datasetOrNothing());
      if (this.filter) {
        hashStr += "/" + this.filter.toHash();
      }
      return hashStr;
    }

    public isAdditive(): boolean {
      return true;
    }
  }

  export class SumApply extends FacetApply {
    static fromJS(parameters: FacetApplyJS, datasetContext: string = DEFAULT_DATASET): SumApply {
      return new SumApply(convertToValue(parameters, datasetContext), datasetContext);
    }

    constructor(parameters: string, datasetContext?: string);
    constructor(parameters: FacetApplyValue, datasetContext?: string);
    constructor(parameters: any, datasetContext: string = DEFAULT_DATASET) {
      if (typeof parameters === 'string') parameters = {attribute: parameters};
      super(parameters, datasetContext, dummyObject);
      var filter = parameters.filter;

      if (filter) {
        this.filter = FacetFilter.fromJS(filter);
      }
      this._ensureAggregate("sum");
      this._verifyName();
      this._verifyAttribute();
    }

    public toString(): string {
      return this._addNameToString(this.aggregate + "(`" + this.attribute + "`)");
    }

    public toHash(): string {
      var hashStr = "SM:" + (this._datasetWithAttribute());
      if (this.filter) {
        hashStr += "/" + this.filter.toHash();
      }
      return hashStr;
    }

    public isAdditive(): boolean {
      return true;
    }
  }

  export class AverageApply extends FacetApply {
    static fromJS(parameters: FacetApplyJS, datasetContext: string = DEFAULT_DATASET): AverageApply {
      return new AverageApply(convertToValue(parameters, datasetContext), datasetContext);
    }

    constructor(parameters: FacetApplyValue, datasetContext: string = DEFAULT_DATASET) {
      super(parameters, datasetContext, dummyObject);
      var filter = parameters.filter;

      if (filter) {
        this.filter = FacetFilter.fromJS(filter);
      }
      this._ensureAggregate("average");
      this._verifyName();
      this._verifyAttribute();
    }

    public toString(): string {
      return this._addNameToString(this.aggregate + "(`" + this.attribute + "`)");
    }

    public toHash(): string {
      var hashStr = "AV:" + (this._datasetWithAttribute());
      if (this.filter) {
        hashStr += "/" + this.filter.toHash();
      }
      return hashStr;
    }

    public decomposeAverage(): DivideApply {
      return DivideApply.fromJS({
        name: this.name,
        dataset: this.dataset,
        operands: [
          {aggregate: 'sum', attribute: this.attribute},
          {aggregate: 'count'}
        ]
      });
    }
  }

  export class MinApply extends FacetApply {
    static fromJS(parameters: FacetApplyJS, datasetContext: string = DEFAULT_DATASET): MinApply {
      return new MinApply(convertToValue(parameters, datasetContext), datasetContext);
    }

    constructor(parameters: FacetApplyValue, datasetContext: string = DEFAULT_DATASET) {
      super(parameters, datasetContext, dummyObject);
      var filter = parameters.filter;

      if (filter) {
        this.filter = FacetFilter.fromJS(filter);
      }
      this._ensureAggregate("min");
      this._verifyName();
      this._verifyAttribute();
    }

    public toString(): string {
      return this._addNameToString(this.aggregate + "(`" + this.attribute + "`)");
    }

    public toHash(): string {
      var hashStr = "MN:" + (this._datasetWithAttribute());
      if (this.filter) {
        hashStr += "/" + this.filter.toHash();
      }
      return hashStr;
    }

    public valueOf(): FacetApplyValue {
      var apply = super.valueOf();
      apply.attribute = this.attribute;
      return apply;
    }
  }

  export class MaxApply extends FacetApply {
    static fromJS(parameters: FacetApplyJS, datasetContext: string = DEFAULT_DATASET): MaxApply {
      return new MaxApply(convertToValue(parameters, datasetContext), datasetContext);
    }

    constructor(parameters: FacetApplyValue, datasetContext: string = DEFAULT_DATASET) {
      super(parameters, datasetContext, dummyObject);
      var filter = parameters.filter;

      if (filter) {
        this.filter = FacetFilter.fromJS(filter);
      }
      this._ensureAggregate("max");
      this._verifyName();
      this._verifyAttribute();
    }

    public toString(): string {
      return this._addNameToString(this.aggregate + "(`" + this.attribute + "`)");
    }

    public toHash(): string {
      var hashStr = "MX:" + (this._datasetWithAttribute());
      if (this.filter) {
        hashStr += "/" + this.filter.toHash();
      }
      return hashStr;
    }
  }

  export class UniqueCountApply extends FacetApply {
    static fromJS(parameters: FacetApplyJS, datasetContext: string = DEFAULT_DATASET): UniqueCountApply {
      return new UniqueCountApply(convertToValue(parameters, datasetContext), datasetContext);
    }

    constructor(parameters: FacetApplyValue, datasetContext: string = DEFAULT_DATASET) {
      super(parameters, datasetContext, dummyObject);
      var filter = parameters.filter;

      if (filter) {
        this.filter = FacetFilter.fromJS(filter);
      }
      this._ensureAggregate("uniqueCount");
      this._verifyName();
      this._verifyAttribute();
    }

    public toString(): string {
      return this._addNameToString(this.aggregate + "(`" + this.attribute + "`)");
    }

    public toHash(): string {
      var hashStr = "UC:" + (this._datasetWithAttribute());
      if (this.filter) hashStr += "/" + this.filter.toHash();
      return hashStr;
    }
  }

  export class QuantileApply extends FacetApply {
    static fromJS(parameters: FacetApplyJS, datasetContext: string = DEFAULT_DATASET): QuantileApply {
      return new QuantileApply(convertToValue(parameters, datasetContext), datasetContext);
    }

    public quantile: number;

    constructor(parameters: FacetApplyValue, datasetContext: string = DEFAULT_DATASET) {
      super(parameters, datasetContext, dummyObject);
      var quantile = parameters.quantile;

      if (typeof quantile !== "number") {
        throw new TypeError("quantile must be a number");
      }
      if (quantile < 0 || 1 < quantile) {
        throw new Error("quantile must be between 0 and 1 (is: " + quantile + ")");
      }
      this.quantile = quantile;
      this._ensureAggregate("quantile");
      this._verifyName();
      this._verifyAttribute();
    }

    public toString(): string {
      return this._addNameToString("quantile(" + this.attribute + ", " + this.quantile + ")");
    }

    public toHash(): string {
      var hashStr = "QT:" + this.attribute + ":" + this.quantile;
      if (this.filter) {
        hashStr += "/" + this.filter.toHash();
      }
      return hashStr;
    }

    public valueOf(): FacetApplyValue {
      var apply = super.valueOf();
      apply.quantile = this.quantile;
      return apply;
    }

    public toJS(): FacetApplyJS {
      var apply = super.toJS();
      apply.quantile = this.quantile;
      return apply;
    }

    public equals(other: FacetApply): boolean {
      return super.equals(other) &&
        this.quantile === (<QuantileApply>other).quantile;
    }

    public isAdditive(): boolean {
      return true;
    }
  }

  export class AddApply extends FacetApply {
    static fromJS(parameters: FacetApplyJS, datasetContext: string = DEFAULT_DATASET): AddApply {
      return new AddApply(convertToValue(parameters, datasetContext), datasetContext);
    }

    constructor(parameters: FacetApplyValue, datasetContext: string = DEFAULT_DATASET) {
      super(parameters, datasetContext, dummyObject);
      this.arithmetic = parameters.arithmetic;
      this.operands = parameters.operands;
      this._verifyName();
      this._ensureArithmetic("add");
    }

    public toString(from: string = "add"): string {
      var expr = (this.operands[0].toString(this.arithmetic)) + " + " + (this.operands[1].toString(this.arithmetic));
      if (from === "divide" || from === "multiply") {
        expr = "(" + expr + ")";
      }
      return this._addNameToString(expr);
    }

    public toHash(): string {
      return (this.operands[0].toHash()) + "+" + (this.operands[1].toHash());
    }

    public isAdditive(): boolean {
      return this.operands[0].isAdditive() &&
        this.operands[1].isAdditive();
    }
  }

  export class SubtractApply extends FacetApply {
    static fromJS(parameters: FacetApplyJS, datasetContext: string = DEFAULT_DATASET): SubtractApply {
      return new SubtractApply(convertToValue(parameters, datasetContext), datasetContext);
    }

    constructor(parameters: FacetApplyValue, datasetContext: string = DEFAULT_DATASET) {
      super(parameters, datasetContext, dummyObject);
      var name = parameters.name;
      this.arithmetic = parameters.arithmetic;
      this.operands = parameters.operands;
      if (name) this.name = name;
      this._verifyName();
      this._ensureArithmetic("subtract");
    }

    public toString(from: string = "add"): string {
      var expr = (this.operands[0].toString(this.arithmetic)) + " - " + (this.operands[1].toString(this.arithmetic));
      if (from === "divide" || from === "multiply") expr = "(" + expr + ")";
      return this._addNameToString(expr);
    }

    public toHash(): string {
      return (this.operands[0].toHash()) + "-" + (this.operands[1].toHash());
    }

    public isAdditive(): boolean {
      return this.operands[0].isAdditive() &&
        this.operands[1].isAdditive();
    }
  }

  export class MultiplyApply extends FacetApply {
    static fromJS(parameters: FacetApplyJS, datasetContext: string = DEFAULT_DATASET): MultiplyApply {
      return new MultiplyApply(convertToValue(parameters, datasetContext), datasetContext);
    }

    constructor(parameters: FacetApplyValue, datasetContext: string = DEFAULT_DATASET) {
      super(parameters, datasetContext, dummyObject);
      this.arithmetic = parameters.arithmetic;
      this.operands = parameters.operands;
      this._verifyName();
      this._ensureArithmetic("multiply");
    }

    public toString(from: string = "add"): string {
      var expr = (this.operands[0].toString(this.arithmetic)) + " * " + (this.operands[1].toString(this.arithmetic));
      if (from === "divide") {
        expr = "(" + expr + ")";
      }
      return this._addNameToString(expr);
    }

    public toHash(): string {
      return (this.operands[0].toHash()) + "*" + (this.operands[1].toHash());
    }

    public isAdditive(): boolean {
      return (isInstanceOf(this.operands[0], ConstantApply) && this.operands[1].isAdditive()) ||
        (this.operands[0].isAdditive() && isInstanceOf(this.operands[1], ConstantApply));
    }
  }

  export class DivideApply extends FacetApply {
    static fromJS(parameters: FacetApplyJS, datasetContext: string = DEFAULT_DATASET): DivideApply {
      return new DivideApply(convertToValue(parameters, datasetContext), datasetContext);
    }

    constructor(parameters: FacetApplyValue, datasetContext: string = DEFAULT_DATASET) {
      super(parameters, datasetContext, dummyObject);
      this.arithmetic = parameters.arithmetic;
      this.operands = parameters.operands;
      this._verifyName();
      this._ensureArithmetic("divide");
    }

    public toString(from: string = "add"): string {
      var expr = (this.operands[0].toString(this.arithmetic)) + " / " + (this.operands[1].toString(this.arithmetic));
      if (from === "divide") expr = "(" + expr + ")";
      return this._addNameToString(expr);
    }

    public toHash(): string {
      return (this.operands[0].toHash()) + "/" + (this.operands[1].toHash());
    }

    public isAdditive(): boolean {
      return this.operands[0].isAdditive() &&
        isInstanceOf(this.operands[1], ConstantApply);
    }
  }

  FacetApply.aggregateClassMap = {
    "constant": ConstantApply,
    "count": CountApply,
    "sum": SumApply,
    "average": AverageApply,
    "min": MinApply,
    "max": MaxApply,
    "uniqueCount": UniqueCountApply,
    "quantile": QuantileApply
  };

  FacetApply.arithmeticClassMap = {
    "add": AddApply,
    "subtract": SubtractApply,
    "multiply": MultiplyApply,
    "divide": DivideApply
  };
}