module Legacy {
  export interface FacetSplitJS {
    operation?: string;
    name?: string;
    bucket?: string;
    attribute?: string;
    dataset?: string;
    segmentFilter?: FacetSegmentFilterJS;
    options?: FacetOptionsJS;
    offset?: number;
    size?: number;
    lowerLimit?: number;
    upperLimit?: number;
    timezone?: string;
    period?: string;
    warp?: string;
    warpDirection?: number;
    splits?: FacetSplitJS[];
  }

  export interface FacetSplitValue {
    name?: string;
    bucket?: string;
    attribute?: string;
    dataset?: string;
    segmentFilter?: FacetSegmentFilter;
    options?: FacetOptions;
    offset?: number;
    size?: number;
    lowerLimit?: number;
    upperLimit?: number;
    timezone?: Timezone;
    period?: Duration;
    warp?: Duration;
    warpDirection?: number;
    splits?: FacetSplit[];
  }

  function convertToValue(js: FacetSplitJS): FacetSplitValue {
    var value: FacetSplitValue = {
      name: js.name,
      bucket: js.bucket,
      attribute: js.attribute,
      dataset: js.dataset
    };
    if (js.segmentFilter) value.segmentFilter = FacetSegmentFilter.fromJS(js.segmentFilter);
    if (js.options) value.options = FacetOptions.fromJS(js.options);
    return value;
  }

  var check: ImmutableClass<FacetSplitValue, FacetSplitJS>;
  export class FacetSplit implements ImmutableInstance<FacetSplitValue, FacetSplitJS> {
    static isFacetSplit(candidate: any): boolean {
      return isInstanceOf(candidate, FacetSplit);
    }

    static classMap: any;

    static fromJS(parameters: FacetSplitJS): FacetSplit {
      if (typeof parameters !== "object") {
        throw new Error("unrecognizable split");
      }
      if (!parameters.hasOwnProperty("bucket")) {
        throw new Error("bucket must be defined");
      }
      if (typeof parameters.bucket !== "string") {
        throw new Error("bucket must be a string");
      }
      var SplitConstructor = FacetSplit.classMap[parameters.bucket];
      if (!SplitConstructor) {
        throw new Error("unsupported bucket '" + parameters.bucket + "'");
      }
      return SplitConstructor.fromJS(parameters);
    }

    public operation = "split";
    public name: string;
    public bucket: string;
    public attribute: string;
    public dataset: string;
    public segmentFilter: FacetSegmentFilter;
    public options: FacetOptions;

    constructor(parameters: FacetSplitValue, dummy: Dummy = null) {
      this.bucket = parameters.bucket;
      this.dataset = parameters.dataset;
      if (dummy !== dummyObject) {
        throw new TypeError("can not call `new FacetSplit` directly use FacetSplit.fromJS instead");
      }
      if (parameters.name) {
        this.name = parameters.name;
      }
      if (parameters.attribute) {
        this.attribute = parameters.attribute;
      }
      if (parameters.segmentFilter) {
        this.segmentFilter = parameters.segmentFilter;
      }
      if (parameters.options) {
        this.options = parameters.options;
      }
    }

    public _ensureBucket(bucket: string): void {
      if (!this.bucket) {
        this.bucket = bucket;
        return;
      }
      if (this.bucket !== bucket) {
        throw new TypeError("incorrect split bucket '" + this.bucket + "' (needs to be: '" + bucket + "')");
      }
    }

    public _verifyName(): void {
      if (!this.name) return;
      if (typeof this.name !== "string") {
        throw new TypeError("split name must be a string");
      }
    }

    public _verifyAttribute(): void {
      if (typeof this.attribute !== "string") {
        throw new TypeError("attribute must be a string");
      }
    }

    public _addName(str: string): string {
      if (!this.name) {
        return str;
      }
      return str + " -> " + this.name;
    }

    public addName(name: string): FacetSplit {
      var splitJS = this.toJS();
      splitJS.name = name;
      return FacetSplit.fromJS(splitJS);
    }

    public toString(): string {
      return this._addName("base split");
    }

    public toHash(): string {
      throw new Error("can not call FacetSplit.toHash directly");
    }

    public valueOf(): FacetSplitValue {
      var split: FacetSplitValue = {
        bucket: this.bucket
      };
      if (this.name) {
        split.name = this.name;
      }
      if (this.attribute) {
        split.attribute = this.attribute;
      }
      if (this.dataset) {
        split.dataset = this.dataset;
      }
      if (this.segmentFilter) {
        split.segmentFilter = this.segmentFilter;
      }
      if (this.options) {
        split.options = this.options;
      }
      return split;
    }

    public toJS(): FacetSplitJS {
      var split: FacetSplitJS = {
        bucket: this.bucket
      };
      if (this.name) {
        split.name = this.name;
      }
      if (this.attribute) {
        split.attribute = this.attribute;
      }
      if (this.dataset) {
        split.dataset = this.dataset;
      }
      if (this.segmentFilter) {
        split.segmentFilter = this.segmentFilter.toJS();
      }
      if (this.options) {
        split.options = this.options.toJS();
      }
      return split;
    }

    public toJSON(): FacetSplitJS {
      return this.toJS();
    }

    public getDataset(): string {
      return this.dataset || "main";
    }

    public getDatasets(): string[] {
      return [this.dataset || "main"];
    }

    public getFilterFor(prop: Prop, fallbackName: string = null): FacetFilter {
      throw new Error("this method should never be called directly");
    }

    public getFilterByDatasetFor(prop: Prop): FiltersByDataset {
      var filterByDataset: FiltersByDataset = {};
      filterByDataset[this.getDataset()] = this.getFilterFor(prop);
      return filterByDataset;
    }

    public equals(other: FacetSplit, compareSegmentFilter = false) {
      return FacetSplit.isFacetSplit(other) &&
        this.bucket === other.bucket &&
        this.attribute === other.attribute &&
        Boolean(this.options) === Boolean(other.options) &&
        (!this.options || this.options.equals(other.options)) &&
        (!compareSegmentFilter || (Boolean(this.segmentFilter) === Boolean(other.segmentFilter && this.segmentFilter.equals(other.segmentFilter))));
    }

    public getAttributes(): string[] {
      return [this.attribute];
    }

    public withoutSegmentFilter(): FacetSplit {
      if (!this.segmentFilter) return this;
      var spec = this.toJS();
      delete spec.segmentFilter;
      return FacetSplit.fromJS(spec);
    }
  }
  check = FacetSplit;

  export class IdentitySplit extends FacetSplit {
    static fromJS(parameters: FacetSplitJS): IdentitySplit {
      return new IdentitySplit(convertToValue(parameters));
    }

    constructor(parameters: FacetSplitValue) {
      super(parameters, dummyObject);
      this._ensureBucket("identity");
      this._verifyName();
      this._verifyAttribute();
    }

    public toString(): string {
      return this._addName(this.bucket + "(`" + this.attribute + "`)");
    }

    public toHash(): string {
      return "ID:" + this.attribute;
    }

    public getFilterFor(prop: Prop, fallbackName: string = null): FacetFilter {
      var name = this.name || fallbackName;
      return new IsFilter({
        attribute: this.attribute,
        value: <any>(prop[name])
      });
    }
  }

  export class ContinuousSplit extends FacetSplit {
    static fromJS(parameters: FacetSplitJS): ContinuousSplit {
      var splitValue = convertToValue(parameters);
      splitValue.offset = parameters.offset;
      splitValue.size = parameters.size;
      splitValue.lowerLimit = parameters.lowerLimit;
      splitValue.upperLimit = parameters.upperLimit;
      return new ContinuousSplit(splitValue);
    }

    public offset: number;
    public size: number;
    public lowerLimit: number;
    public upperLimit: number;

    constructor(parameters: FacetSplitValue) {
      super(parameters, dummyObject);
      this.size = parameters.size;
      this.offset = parameters.offset;
      var lowerLimit = parameters.lowerLimit;
      var upperLimit = parameters.upperLimit;

      if (this.offset == null) {
        this.offset = 0;
      }
      if (lowerLimit != null) {
        this.lowerLimit = lowerLimit;
      }
      if (upperLimit != null) {
        this.upperLimit = upperLimit;
      }
      if (typeof this.size !== "number") {
        throw new TypeError("size must be a number");
      }
      if (this.size <= 0) {
        throw new Error("size must be positive (is: " + this.size + ")");
      }
      if (typeof this.offset !== "number") {
        throw new TypeError("offset must be a number");
      }
      this._ensureBucket("continuous");
      this._verifyName();
      this._verifyAttribute();
    }

    public toString(): string {
      return this._addName(this.bucket + "(`" + this.attribute + "`, " + this.size + ", " + this.offset + ")");
    }

    public toHash(): string {
      return "CT:" + this.attribute + ":" + this.size + ":" + this.offset;
    }

    public valueOf(): FacetSplitValue {
      var split = super.valueOf();
      split.size = this.size;
      split.offset = this.offset;
      if (this.lowerLimit != null) split.lowerLimit = this.lowerLimit;
      if (this.upperLimit != null) split.upperLimit = this.upperLimit;
      return split;
    }

    public toJS(): FacetSplitJS {
      var split = super.toJS();
      split.size = this.size;
      split.offset = this.offset;
      if (this.lowerLimit != null) split.lowerLimit = this.lowerLimit;
      if (this.upperLimit != null) split.upperLimit = this.upperLimit;
      return split;
    }

    public getFilterFor(prop: Prop, fallbackName: string = null): FacetFilter {
      var name = this.name || fallbackName;
      var propRange: any[] = <any>prop[name];
      return new WithinFilter({
        attribute: this.attribute,
        range: propRange
      });
    }

    public equals(other: FacetSplit, compareSegmentFilter: boolean = false): boolean {
      return super.equals(other, compareSegmentFilter) &&
        this.size === (<ContinuousSplit>other).size &&
        this.offset === (<ContinuousSplit>other).offset &&
        this.lowerLimit === (<ContinuousSplit>other).lowerLimit &&
        this.upperLimit === (<ContinuousSplit>other).upperLimit;
    }
  }

  export class TimePeriodSplit extends FacetSplit {
    static fromJS(parameters: FacetSplitJS): TimePeriodSplit {
      var splitValue: FacetSplitValue = convertToValue(parameters);
      if (parameters.period) {
        splitValue.period = Duration.fromJS(parameters.period);
      } else {
        throw new Error("Must have period");
      }
      if (parameters.warp) {
        splitValue.warp = Duration.fromJS(parameters.warp);
        splitValue.warpDirection = parameters.warpDirection || 1;
      }
      if (parameters.timezone) {
        splitValue.timezone = Timezone.fromJS(parameters.timezone);
      } else {
        splitValue.timezone = Timezone.UTC();
      }
      return new TimePeriodSplit(splitValue);
    }

    public timezone: Timezone;
    public period: Duration;
    public warp: Duration;
    public warpDirection: number;

    constructor(parameters: FacetSplitValue) {
      super(parameters, dummyObject);
      this.period = parameters.period;
      this.timezone = parameters.timezone;
      this.warp = parameters.warp;
      this.warpDirection = parameters.warpDirection;

      if (!Duration.isDuration(this.period)) {
        throw new TypeError("must have period");
      }
      if (!this.period.isSimple()) {
        throw new TypeError("the period must be in simple");
      }
      if (!Timezone.isTimezone(this.timezone)) {
        throw new TypeError("must have timezone");
      }
      if (this.warp) {
        if (!Duration.isDuration(this.warp)) {
          throw new TypeError("warp must be a duration");
        }
        if (Math.abs(this.warpDirection) !== 1) {
          throw new TypeError("warpDirection must be 1 or -1");
        }
      }
      this._ensureBucket("timePeriod");
      this._verifyName();
      this._verifyAttribute();
    }

    private _warpString(): string {
      return (this.warpDirection > 0 ? '+' : '-') + this.warp.toString();
    }

    public toString(): string {
      var warpStr = this.warp ? (', ' + this._warpString()) : '';
      return this._addName(this.bucket + "(`" + this.attribute + "`, " + this.period.toString() + warpStr + ", " + this.timezone + ")");
    }

    public toHash(): string {
      var warpStr = this.warp ? (':' + this._warpString()) : '';
      return "TP:" + this.attribute + ":" + this.period + ":" + this.timezone + warpStr;
    }

    public valueOf(): FacetSplitValue {
      var split = super.valueOf();
      split.period = this.period;
      split.timezone = this.timezone;
      if (this.warp) {
        split.warp = this.warp;
        if (this.warpDirection === -1) split.warpDirection = -1;
      }
      return split;
    }

    public toJS(): FacetSplitJS {
      var split = super.toJS();
      split.period = this.period.toJS();
      split.timezone = this.timezone.toJS();
      if (this.warp) {
        split.warp = this.warp.toJS();
        if (this.warpDirection === -1) split.warpDirection = -1;
      }
      return split;
    }

    public getFilterFor(prop: Prop, fallbackName: string = null): FacetFilter {
      var name = this.name || fallbackName;
      var propRange: any[] = <any>(prop[name]);
      var warp = this.warp;
      if (warp) {
        var timezone = this.timezone;
        propRange = propRange.map((d) => warp.move(d, timezone, this.warpDirection));
      }
      return new WithinFilter({
        attribute: this.attribute,
        range: propRange
      });
    }

    public equals(other: FacetSplit, compareSegmentFilter: boolean = false): boolean {
      return super.equals(other, compareSegmentFilter) &&
        this.period.equals((<TimePeriodSplit>other).period) &&
        this.timezone.equals((<TimePeriodSplit>other).timezone) &&
        Boolean(this.warp) === Boolean((<TimePeriodSplit>other).warp) &&
        (!this.warp || this.warp.equals((<TimePeriodSplit>other).warp)) &&
        this.warpDirection === (<TimePeriodSplit>other).warpDirection;
    }
  }

  export class TupleSplit extends FacetSplit {
    static fromJS(parameters: FacetSplitJS): TupleSplit {
      var splitValue = convertToValue(parameters);
      splitValue.splits = parameters.splits.map(FacetSplit.fromJS);
      return new TupleSplit(splitValue);
    }

    public splits: FacetSplit[];

    constructor(parameters: FacetSplitValue) {
      super(parameters, dummyObject);
      this.splits = parameters.splits;
      if (!(Array.isArray(this.splits) && this.splits.length)) {
        throw new TypeError("splits must be a non-empty array");
      }
      this.splits.forEach((split) => {
        if (split.bucket === "tuple") {
          throw new Error("tuple splits can not be nested");
        }
        if (!split.hasOwnProperty("name")) {
          throw new Error("a split within a tuple must have a name");
        }
        if (split.hasOwnProperty("segmentFilter")) {
          throw new Error("a split within a tuple should not have a segmentFilter");
        }
      });
      this._ensureBucket("tuple");
    }

    public toString(): string {
      return this._addName("(" + (this.splits.join(" x ")) + ")");
    }

    public toHash(): string {
      return "(" + this.splits.map((split) => split.toHash()).join(")*(") + ")";
    }

    public valueOf(): FacetSplitValue {
      var split = super.valueOf();
      split.splits = this.splits;
      return split;
    }

    public toJS(): FacetSplitJS {
      var split = super.toJS();
      split.splits = this.splits.map((split) => split.toJS());
      return split;
    }

    public getFilterFor(prop: Prop): FacetFilter {
      var name = this.name;
      return new AndFilter(this.splits.map((split) => split.getFilterFor(prop, name)));
    }

    public equals(other: FacetSplit, compareSegmentFilter: boolean = false): boolean {
      if (!super.equals(other, compareSegmentFilter)) return false;
      var otherSplits = (<ParallelSplit>other).splits;
      return this.splits.length === otherSplits.length &&
        this.splits.every((split, i) => split.equals(otherSplits[i], true));
    }

    public getAttributes(): string[] {
      return this.splits.map((parameters) => {
        return parameters.attribute;
      }).sort();
    }
  }

  export class ParallelSplit extends FacetSplit {
    static fromJS(parameters: FacetSplitJS): ParallelSplit {
      var splitValue = convertToValue(parameters);
      splitValue.splits = parameters.splits.map(FacetSplit.fromJS);
      return new ParallelSplit(splitValue);
    }

    public splits: FacetSplit[];

    constructor(parameters: FacetSplitValue) {
      super(parameters, dummyObject);
      this.splits = parameters.splits;
      if (!(Array.isArray(this.splits) && this.splits.length)) {
        throw new TypeError("splits must be a non-empty array");
      }
      this.splits.forEach((split) => {
        if (split.bucket === "parallel") {
          throw new Error("parallel splits can not be nested");
        }
        if (split.hasOwnProperty("name")) {
          throw new Error("a split within a parallel must not have a name");
        }
        if (split.hasOwnProperty("segmentFilter")) {
          throw new Error("a split within a parallel should not have a segmentFilter");
        }
      });
      this._ensureBucket("parallel");
    }

    public toString(): string {
      return this._addName(this.splits.join(" | "));
    }

    public toHash(): string {
      return "(" + this.splits.map((split) => split.toHash()).join(")|(") + ")";
    }

    public valueOf(): FacetSplitValue {
      var split = super.valueOf();
      split.splits = this.splits;
      return split;
    }

    public toJS(): FacetSplitJS {
      var split = super.toJS();
      split.splits = this.splits.map((split) => split.toJS());
      return split;
    }

    public getFilterFor(prop: Prop, fallbackName: string = null): FacetFilter {
      var name = this.name || fallbackName;
      var firstSplit = this.splits[0];
      var value: any = <any>(prop[name]);
      switch (firstSplit.bucket) {
        case "identity":
          return new IsFilter({
            attribute: firstSplit.attribute,
            value: value
          });
        case "continuous":
        case "timePeriod":
          return new WithinFilter({
            attribute: firstSplit.attribute,
            range: <any[]>value
          });
        default:
          throw new Error("unsupported sub split '" + firstSplit.bucket + "'");
      }
    }

    public getFilterByDatasetFor(prop: Prop): FiltersByDataset {
      var name = this.name;
      var filterByDataset: FiltersByDataset = {};
      this.splits.forEach((split) => filterByDataset[split.getDataset()] = split.getFilterFor(prop, name));
      return filterByDataset;
    }

    public equals(other: FacetSplit, compareSegmentFilter: boolean = false): boolean {
      if (!super.equals(other, compareSegmentFilter)) return false;
      var otherSplits = (<ParallelSplit>other).splits;
      return this.splits.length === otherSplits.length &&
        this.splits.every((split, i) => split.equals(otherSplits[i], true));
    }

    public getDataset(): string {
      throw new Error("getDataset not defined for ParallelSplit, use getDatasets");
    }

    public getDatasets(): string[] {
      return this.splits.map((split) => split.getDataset());
    }

    public getAttributes(): string[] {
      var attributes: string[] = [];
      this.splits.forEach((split) => {
        split.getAttributes().map((attribute) => {
          if (attributes.indexOf(attribute) < 0) {
            return attributes.push(attribute);
          }
        });
      });
      return attributes.sort();
    }
  }

  FacetSplit.classMap = {
    "identity": IdentitySplit,
    "continuous": ContinuousSplit,
    "timePeriod": TimePeriodSplit,
    "tuple": TupleSplit,
    "parallel": ParallelSplit
  };
}

