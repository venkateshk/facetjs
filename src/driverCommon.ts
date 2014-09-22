"use strict";

import FacetQueryModule = require("query/query");
import FacetQuery = FacetQueryModule.FacetQuery;

import SegmentTreeModule = require("query/segmentTree");
import SegmentTree = SegmentTreeModule.SegmentTree;

module Driver {
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

export = Driver;