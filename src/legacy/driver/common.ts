module Legacy {
  export module Driver {
    export interface Request {
      query: FacetQuery;
      context?: { [key: string]: any };
    }

    export interface IntermediateCallback {
      (result: SegmentTree): void
    }

    export interface AttributeIntrospect {
      name: string;
      time?: boolean;
      numeric?: boolean;
      integer?: boolean;
      categorical?: boolean;
    }

    export interface FacetDriver {
      (request: Request): Q.Promise<SegmentTree>;
      introspect: (options: any) => Q.Promise<AttributeIntrospect[]>;
    }
  }
}
