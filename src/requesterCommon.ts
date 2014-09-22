"use strict";

module Requester {
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

export = Requester;