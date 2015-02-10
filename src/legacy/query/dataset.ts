module Legacy {
  export interface FacetDatasetJS {
    operation?: string;
    name?: string;
    source?: string;
    filter?: FacetFilterJS;
  }

  export interface FacetDatasetValue {
    name?: string;
    source?: string;
    filter: FacetFilter;
  }

  var check: ImmutableClass<FacetDatasetValue, FacetDatasetJS>;
  export class FacetDataset implements ImmutableInstance<FacetDatasetValue, FacetDatasetJS> {
    static BASE: FacetDataset;

    static isFacetDataset(candidate: any): boolean {
      return isInstanceOf(candidate, FacetDataset);
    }

    static fromJS(parameters: FacetDatasetJS): FacetDataset {
      return new FacetDataset({
        name: parameters.name,
        source: parameters.source,
        filter: parameters.filter ? FacetFilter.fromJS(parameters.filter) : FacetFilter.TRUE
      });
    }

    public name: string;
    public source: string;
    public filter: FacetFilter;

    constructor(parameters: FacetDatasetValue) {
      this.name = parameters.name;
      this.source = parameters.source;
      if (typeof this.name !== "string") {
        throw new TypeError("dataset name must be a string");
      }
      if (typeof this.source !== "string") {
        throw new TypeError("dataset source must be a string");
      }
      if (!FacetFilter.isFacetFilter(parameters.filter)) {
        throw new TypeError("filter must be a FacetFilter");
      }
      this.filter = parameters.filter;
    }

    public toString(): string {
      return "Dataset:" + this.name;
    }

    public getFilter(): FacetFilter {
      return this.filter;
    }

    public and(filter: FacetFilter): FacetDataset {
      var value = this.valueOf();
      value.filter = new AndFilter([value.filter, filter]).simplify();
      return new FacetDataset(value);
    }

    public valueOf(): FacetDatasetValue {
      var spec: FacetDatasetValue = {
        name: this.name,
        source: this.source,
        filter: this.filter
      };
      return spec;
    }

    public toJS() {
      var spec: FacetDatasetJS = {
        source: this.source
      };
      if (this.name) {
        spec.name = this.name
      }
      if (this.filter.type !== 'true') {
        spec.filter = this.filter.toJS();
      }
      return spec;
    }

    public toJSON(): FacetDatasetJS {
      return this.toJS();
    }

    public equals(other: FacetDataset) {
      return FacetDataset.isFacetDataset(other) &&
        this.source === other.source &&
        this.getFilter().equals(other.getFilter());
    }
  }
  check = FacetDataset;

  FacetDataset.BASE = new FacetDataset({
    name: "main",
    source: "base",
    filter: FacetFilter.TRUE
  });
}
