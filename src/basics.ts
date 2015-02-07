module Basics {
  export interface Datum {
    [attribute: string]: any;
  }

  export interface Lookup<T> {
    [key: string]: T;
  }

  export interface Dummy {}

  export var dummyObject: Dummy = {};
}
