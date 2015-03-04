module Legacy {
  function parseValue(value: any): any {
    if (!Array.isArray(value)) {
      return value;
    }
    if (value.length !== 2) {
      throw new Error("bad range has length of " + value.length);
    }
    var start = value[0];
    var end = value[1];
    if (typeof start === "string") {
      start = new Date(start);
    }
    if (typeof end === "string") {
      end = new Date(end);
    }
    return [start, end];
  }

  export interface SegmentFilterFn {
    (segment: SegmentTree): boolean;
  }

  export interface FacetSegmentFilterJS {
    type?: string;
    prop?: string;
    value?: any;
    values?: any[];
    filter?: FacetSegmentFilterJS;
    filters?: FacetSegmentFilterJS[];
  }

  export interface FacetSegmentFilterValue {
    type?: string;
    prop?: string;
    value?: any;
    values?: any[];
    filter?: FacetSegmentFilter;
    filters?: FacetSegmentFilter[];
  }

  var check: ImmutableClass<FacetSegmentFilterValue, FacetSegmentFilterJS>;
  export class FacetSegmentFilter implements ImmutableInstance<FacetSegmentFilterValue, FacetSegmentFilterJS> {
    static isFacetSegmentFilter(candidate: any): boolean {
      return isInstanceOf(candidate, FacetSegmentFilter);
    }

    static classMap: any;

    static fromJS(parameters: FacetSegmentFilterJS): FacetSegmentFilter {
      if (typeof parameters !== "object") {
        throw new Error("unrecognizable segment filter");
      }
      if (!hasOwnProperty(parameters, "type")) {
        throw new Error("type must be defined");
      }
      if (typeof parameters.type !== "string") {
        throw new Error("type must be a string");
      }
      var SegmentFilterConstructor = FacetSegmentFilter.classMap[parameters.type];
      if (!SegmentFilterConstructor) {
        throw new Error("unsupported segment filter type '" + parameters.type + "'");
      }
      return SegmentFilterConstructor.fromJS(parameters);
    }

    public type: string;
    public prop: string;

    constructor(parameters: FacetSegmentFilterValue, dummy: Dummy = null) {
      this.type = parameters.type;
      this.prop = parameters.prop;
      if (dummy !== dummyObject) {
        throw new TypeError("can not call `new FacetSegmentFilter` directly use FacetSegmentFilter.fromJS instead");
      }
    }

    public _ensureType(filterType: string): void {
      if (!this.type) {
        this.type = filterType;
        return;
      }
      if (this.type !== filterType) {
        throw new TypeError("incorrect segment filter type '" + this.type + "' (needs to be: '" + filterType + "')");
      }
    }

    public _validateProp(): void {
      if (typeof this.prop !== "string") {
        throw new TypeError("prop must be a string");
      }
    }

    public valueOf(): FacetSegmentFilterValue {
      return {
        type: this.type
      };
    }

    public toJS(): FacetSegmentFilterJS {
      return {
        type: this.type
      };
    }

    public toJSON(): FacetSegmentFilterJS {
      return this.toJS();
    }

    public equals(other: FacetSegmentFilter) {
      return FacetSegmentFilter.isFacetSegmentFilter(other) &&
        this.type === other.type &&
        this.prop === other.prop;
    }

    /**
     * Returns the JS function that does the filtering
     * @returns SegmentFilterFn
     */
    public getFilterFn(): SegmentFilterFn {
      throw new Error("this must never be called directly");
    }
  }
  check = FacetSegmentFilter;

  export class TrueSegmentFilter extends FacetSegmentFilter {
    static fromJS(parameters: FacetSegmentFilterJS): TrueSegmentFilter {
      return new TrueSegmentFilter(<FacetSegmentFilterValue>parameters);
    }

    constructor(parameters: FacetSegmentFilterValue = {}) {
      super(parameters, dummyObject);
      this._ensureType("true");
    }

    public toString() {
      return "Every segment";
    }

    public getFilterFn(): SegmentFilterFn {
      return () => true;
    }
  }

  export class FalseSegmentFilter extends FacetSegmentFilter {
    static fromJS(parameters: FacetSegmentFilterJS): FalseSegmentFilter {
      return new FalseSegmentFilter(<FacetSegmentFilterValue>parameters);
    }

    constructor(parameters: FacetSegmentFilterValue = {}) {
      super(parameters, dummyObject);
      this.type = parameters.type;
      this._ensureType("false");
    }

    public toString() {
      return "No segment";
    }

    public getFilterFn(): SegmentFilterFn {
      return () => false;
    }
  }

  export class IsSegmentFilter extends FacetSegmentFilter {
    static fromJS(parameters: FacetSegmentFilterJS): IsSegmentFilter {
      return new IsSegmentFilter(<FacetSegmentFilterValue>parameters);
    }

    public value: any;

    constructor(parameters: FacetSegmentFilterValue) {
      super(parameters, dummyObject);
      this.prop = parameters.prop;
      var value = parameters.value;
      this._ensureType("is");
      this._validateProp();
      this.value = parseValue(value);
    }

    public toString() {
      return "seg#" + this.prop + " is " + this.value;
    }

    public valueOf(): FacetSegmentFilterValue {
      var spec = super.valueOf();
      spec.prop = this.prop;
      spec.value = this.value;
      return spec;
    }

    public toJS(): FacetSegmentFilterJS {
      var spec = super.toJS();
      spec.prop = this.prop;
      spec.value = this.value;
      return spec;
    }

    public equals(other: FacetSegmentFilter): boolean {
      return super.equals(other) &&
        this.value === (<IsSegmentFilter>other).value;
    }

    public getFilterFn(): SegmentFilterFn {
      var myProp = this.prop;
      var myValue = this.value;
      if (Array.isArray(this.value)) {
        var start = myValue[0];
        var end = myValue[1];
        return (segment) => {
          var propValue = segment.getProp(myProp);
          if ((propValue != null ? propValue.length : void 0) !== 2) {
            return false;
          }
          var segStart = propValue[0];
          var segEnd = propValue[1];
          return segStart.valueOf() === start.valueOf() &&
            segEnd.valueOf() === end.valueOf();
        };
      } else {
        return (segment) => segment.getProp(myProp) === myValue;
      }
    }
  }

  export class InSegmentFilter extends FacetSegmentFilter {
    static fromJS(parameters: FacetSegmentFilterJS): InSegmentFilter {
      return new InSegmentFilter(<FacetSegmentFilterValue>parameters);
    }

    public values: any[];

    constructor(parameters: FacetSegmentFilterValue) {
      super(parameters, dummyObject);
      this.prop = parameters.prop;
      var values = parameters.values;
      this._ensureType("in");
      this._validateProp();
      if (!Array.isArray(values)) throw new TypeError("values must be an array");
      this.values = values.map(parseValue);
    }

    public toString() {
      switch (this.values.length) {
        case 0:
          return "No segment";
        case 1:
          return "seg#" + this.prop + " is " + this.values[0];
        case 2:
          return "seg#" + this.prop + " is either " + this.values[0] + " or " + this.values[1];
        default:
          return "seg#" + this.prop + " is one of: " + (specialJoin(this.values, ", ", ", or "));
      }
    }

    public valueOf(): FacetSegmentFilterValue {
      var spec = super.valueOf();
      spec.prop = this.prop;
      spec.values = this.values;
      return spec;
    }

    public toJS(): FacetSegmentFilterJS {
      var spec = super.toJS();
      spec.prop = this.prop;
      spec.values = this.values;
      return spec;
    }

    public equals(other: FacetSegmentFilter): boolean {
      return super.equals(other) &&
        this.values.join(";") === (<InSegmentFilter>other).values.join(";");
    }

    public getFilterFn(): SegmentFilterFn {
      var myProp = this.prop;
      var myValues = this.values;
      return (segment) => {
        return myValues.indexOf(segment.getProp(myProp)) !== -1;
      };
    }
  }

  export class NotSegmentFilter extends FacetSegmentFilter {
    static fromJS(parameters: FacetSegmentFilterJS): NotSegmentFilter {
      return new NotSegmentFilter(FacetSegmentFilter.fromJS(parameters.filter));
    }

    public filter: FacetSegmentFilter;

    constructor(parameters: FacetSegmentFilter);
    constructor(parameters: FacetSegmentFilterValue);
    constructor(parameters: any) {
      if (isInstanceOf(parameters, FacetSegmentFilter)) parameters = {filter: parameters};
      super(parameters, dummyObject);
      this.filter = parameters.filter;
      this._ensureType("not");
    }

    public toString() {
      return "not (" + this.filter + ")";
    }

    public valueOf(): FacetSegmentFilterValue {
      var spec = super.valueOf();
      spec.filter = this.filter;
      return spec;
    }

    public toJS(): FacetSegmentFilterJS {
      var spec = super.toJS();
      spec.filter = this.filter.toJS();
      return spec;
    }

    public equals(other: FacetSegmentFilter): boolean {
      return super.equals(other) &&
        this.filter.equals((<NotSegmentFilter>other).filter);
    }

    public getFilterFn(): SegmentFilterFn {
      var filterFn = this.filter.getFilterFn();
      return (segment) => !filterFn(segment);
    }
  }

  export class AndSegmentFilter extends FacetSegmentFilter {
    static fromJS(parameters: FacetSegmentFilterJS): AndSegmentFilter {
      return new AndSegmentFilter(parameters.filters.map(FacetSegmentFilter.fromJS));
    }

    public filters: FacetSegmentFilter[];

    constructor(parameters: FacetSegmentFilter[]);
    constructor(parameters: FacetSegmentFilterValue);
    constructor(parameters: any) {
      super(parameters, dummyObject);
      if (Array.isArray(parameters)) parameters = {filters: parameters};
      this.type = parameters.type;
      this.filters = parameters.filters;
      if (!Array.isArray(this.filters)) {
        throw new TypeError("filters must be an array");
      }
      this._ensureType("and");
    }

    public toString() {
      if (this.filters.length > 1) {
        return "(" + (this.filters.join(") and (")) + ")";
      } else {
        return String(this.filters[0]);
      }
    }

    public valueOf(): FacetSegmentFilterValue {
      var spec = super.valueOf();
      spec.filters = this.filters;
      return spec;
    }

    public toJS(): FacetSegmentFilterJS {
      var spec = super.toJS();
      spec.filters = this.filters.map((filter) => filter.toJS());
      return spec;
    }

    public equals(other: FacetSegmentFilter): boolean {
      if (!super.equals(other)) return false;
      var otherFilters = (<AndSegmentFilter>other).filters;
      return this.filters.length === otherFilters.length &&
        this.filters.every((filter, i) => filter.equals(otherFilters[i]));
    }

    public getFilterFn(): SegmentFilterFn {
      var filterFns = this.filters.map((filter) => filter.getFilterFn());
      return (segment) => {
        for (var i = 0; i < filterFns.length; i++) {
          var filterFn = filterFns[i];
          if (!filterFn(segment)) {
            return false;
          }
        }
        return true;
      };
    }
  }

  export class OrSegmentFilter extends FacetSegmentFilter {
    static fromJS(parameters: FacetSegmentFilterJS): OrSegmentFilter {
      return new OrSegmentFilter(parameters.filters.map(FacetSegmentFilter.fromJS));
    }

    public filters: FacetSegmentFilter[];

    constructor(parameters: FacetSegmentFilter[]);
    constructor(parameters: FacetSegmentFilterValue);
    constructor(parameters: any) {
      super(parameters, dummyObject);
      if (Array.isArray(parameters)) parameters = {filters: parameters};
      this.type = parameters.type;
      this.filters = parameters.filters;
      if (!Array.isArray(this.filters)) {
        throw new TypeError("filters must be an array");
      }
      this._ensureType("or");
    }

    public toString() {
      if (this.filters.length > 1) {
        return "(" + (this.filters.join(") or (")) + ")";
      } else {
        return String(this.filters[0]);
      }
    }

    public valueOf(): FacetSegmentFilterValue {
      var spec = super.valueOf();
      spec.filters = this.filters;
      return spec;
    }

    public toJS(): FacetSegmentFilterJS {
      var spec = super.toJS();
      spec.filters = this.filters.map((filter) => filter.toJS());
      return spec;
    }

    public equals(other: FacetSegmentFilter): boolean {
      if (!super.equals(other)) return false;
      var otherFilters = (<OrSegmentFilter>other).filters;
      return this.filters.length === otherFilters.length &&
        this.filters.every((filter, i) => filter.equals(otherFilters[i]));
    }

    public getFilterFn(): SegmentFilterFn {
      var filterFns = this.filters.map((filter) => filter.getFilterFn());
      return (segment) => {
        for (var i = 0; i < filterFns.length; i++) {
          var filterFn = filterFns[i];
          if (filterFn(segment)) {
            return true;
          }
        }
        return false;
      };
    }
  }

  FacetSegmentFilter.classMap = {
    "true": TrueSegmentFilter,
    "false": FalseSegmentFilter,
    "is": IsSegmentFilter,
    "in": InSegmentFilter,
    "not": NotSegmentFilter,
    "and": AndSegmentFilter,
    "or": OrSegmentFilter
  };
}
