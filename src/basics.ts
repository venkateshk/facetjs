"use strict";

module Basics {
  export interface Datum {
    [attribute: string]: any;
  }

  export interface Lookup<T> {
    [key: string]: T;
  }
}

export = Basics;
