declare module Requester {
  interface DatabaseRequest<T> {
    query: T;
    context?: { [key: string]: any };
  }

  interface DatabaseCallback {
    (error: Error, result?: any): void
  }

  interface FacetRequester<T> {
    (request: DatabaseRequest<T>, callback: DatabaseCallback): void;
  }
}
