"use strict";

module Locator {
  export interface Location {
    host: string
    port?: number
  }

  export interface Callback {
    (err: Error, location?: Location): void
  }

  export interface FacetLocator {
    (fn: Callback): void

    // Event emitter extension
    addListener?(event: string, listener: Function): any;
    on?(event: string, listener: Function): any;
    once?(event: string, listener: Function): any;
    removeListener?(event: string, listener: Function): any;
    removeAllListeners?(event?: string): any;
    setMaxListeners?(n: number): void;
    listeners?(event: string): Function[];
    emit?(event: string, ...args: any[]): boolean;
  }
}

export = Locator;
