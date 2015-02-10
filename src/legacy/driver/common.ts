module Legacy {
  export module Driver {
    export interface Request {
      query: FacetQuery;
      context?: { [key: string]: any };
    }

    export interface DataCallback {
      (error: Error, result?: SegmentTree): void
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

    export interface IntrospectionCallback {
      (error: Error, attributes?: AttributeIntrospect[]): void
    }

    export interface FacetDriver {
      (request: Request, callback: DataCallback): void;
      introspect: (options: any, callback: IntrospectionCallback) => void;
    }
  }

  export module Requester {
    export interface DatabaseRequest<T> {
      query: T;
      context?: { [key: string]: any };
    }

    export interface DatabaseCallback {
      (error: Error, result?: any): void
    }

    export interface FacetRequester<T> {
      (request: DatabaseRequest<T>, callback: DatabaseCallback): void;
    }
  }
}
