module Legacy {
  export interface FacetCombineJS {
    operation?: string
    method?: string
    sort?: FacetSortJS
    limit?: number
    limits?: number[]
  }

  export interface FacetCombineValue {
    method?: string
    sort?: FacetSort
    limit?: number
    limits?: number[]
  }

  var check: ImmutableClass<FacetCombineValue, FacetCombineJS>;
  export class FacetCombine implements ImmutableInstance<FacetCombineValue, FacetCombineJS> {
    static isFacetCombine(candidate: any): boolean {
      return isInstanceOf(candidate, FacetCombine);
    }

    static classMap: any;

    static fromJS(parameters: FacetCombineValue): FacetCombine {
      if (typeof parameters !== "object") {
        throw new Error("unrecognizable combine");
      }
      if (parameters.method == null) {
        parameters.method = (<any>parameters)['combine']; // Back compatibility
      }
      if (!hasOwnProperty(parameters, "method")) {
        throw new Error("method not defined");
      }
      if (typeof parameters.method !== "string") {
        throw new Error("method must be a string");
      }
      var CombineConstructor = FacetCombine.classMap[parameters.method];
      if (!CombineConstructor) {
        throw new Error("unsupported method " + parameters.method);
      }
      return CombineConstructor.fromJS(parameters);
    }

    public method: string;
    public sort: FacetSort;

    constructor(parameters: FacetCombineValue, dummy: Dummy = null) {
      this.method = parameters.method;
      this.sort = parameters.sort;
      if (dummy !== dummyObject) {
        throw new TypeError("can not call `new FacetCombine` directly use FacetCombine.fromJS instead");
      }
    }

    public _ensureMethod(method: string): void {
      if (!this.method) {
        this.method = method;
        return;
      }
      if (this.method !== method) {
        throw new TypeError("incorrect combine method '" + this.method + "' (needs to be: '" + method + "')");
      }
    }

    public toString(): string {
      return 'BaseCombine';
    }

    public valueOf(): FacetCombineValue {
      return {
        method: this.method,
        sort: this.sort
      };
    }

    public toJS(): FacetCombineJS {
      return {
        method: this.method,
        sort: this.sort.toJS()
      };
    }

    public toJSON() {
      return this.toJS();
    }

    public equals(other: FacetCombine): boolean {
      return FacetCombine.isFacetCombine(other) &&
        this.method === other.method &&
        this.sort.equals(other.sort);
    }
  }
  check = FacetCombine;

  export class SliceCombine extends FacetCombine {
    static fromJS(parameters: FacetCombineJS): SliceCombine {
      return new SliceCombine({
        sort: FacetSort.fromJS(parameters.sort),
        limit: parameters.limit != null ? Number(parameters.limit) : null
      });
    }

    public sort: FacetSort;
    public limit: number;

    constructor(parameters: FacetCombineValue) {
      super(parameters, dummyObject);
      this.sort = parameters.sort;
      var limit = parameters.limit;
      this._ensureMethod("slice");
      if (limit != null) {
        if (typeof limit !== 'number' || isNaN(limit)) {
          throw new TypeError("limit must be a number");
        }
        this.limit = limit;
      }
    }

    public toString(): string {
      return "SliceCombine";
    }

    public valueOf(): FacetCombineValue {
      var combine = super.valueOf();
      if (this.limit != null) combine.limit = this.limit;
      return combine;
    }

    public toJS(): FacetCombineJS {
      var combine = super.toJS();
      if (this.limit != null) combine.limit = this.limit;
      return combine;
    }

    public equals(other: FacetCombine): boolean {
      return super.equals(other) &&
        this.limit === (<SliceCombine>other).limit;
    }
  }

  export class MatrixCombine extends FacetCombine {
    static fromJS(parameters: FacetCombineJS): MatrixCombine {
      return new MatrixCombine({
        sort: FacetSort.fromJS(parameters.sort),
        limits: parameters.limits.map(Number)
      });
    }

    public sort: FacetSort;
    public limits: number[];

    constructor(parameters: FacetCombineValue) {
      super(parameters, dummyObject);
      this.sort = parameters.sort;
      this.limits = parameters.limits;
      this._ensureMethod("matrix");
      if (!Array.isArray(this.limits)) {
        throw new TypeError("limits must be an array");
      }
    }

    public toString(): string {
      return "MatrixCombine";
    }

    public valueOf(): FacetCombineValue {
      var combine = super.valueOf();
      combine.limits = this.limits;
      return combine;
    }

    public toJS(): FacetCombineJS {
      var combine = super.toJS();
      combine.limits = this.limits;
      return combine;
    }

    public equals(other: FacetCombine): boolean {
      return super.equals(other) &&
        this.limits.join(";") === (<MatrixCombine>other).limits.join(";");
    }
  }

  FacetCombine.classMap = {
    "slice": SliceCombine,
    "matrix": MatrixCombine
  };
}
