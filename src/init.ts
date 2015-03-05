/// <reference path="../definitions/require.d.ts" />
/// <reference path="../typings/q/Q.d.ts" />
/// <reference path="../typings/async/async.d.ts" />
/// <reference path="../definitions/higher-object.d.ts" />
/// <reference path="../definitions/chronology.d.ts" />
/// <reference path="../definitions/locator.d.ts" />
/// <reference path="../definitions/requester.d.ts" />
"use strict";

/*========================================*\
 *                                        *
 *              WITCH CRAFT               *
 *                                        *
\*========================================*/

/*
 ~~ Description of Witchcraft ~~

 As of this writing (and my understanding[1]) TypeScript has two module modes: internal and external[2]

 External modules have a 1-1 correspondence with generated JS files and they use can use `import` / `require`
 to load each other and also 3rd party modules.
 Because it relies on require in node it will not work if there are two files, each with a class in it,
 that are interdependent

 example:  dataset.split(...) => Set  and  set.label('blah') => Dataset

 Because so many classes in facet are interdependent and writing the entire program as one file would suck:
 external modules are a no go.

 Internal modules have a nicer syntax and can be split across files and then compiled into one file.
 The modules are "meant" for the web environment where their external dependencies just live in the global scope.
 The only downside is the inability to use traditional `require` for loading other (3rd party) modules.

 The solution / witchcraft:
 Internal modules are used and require is defined as just a function (see ../definitions/require.d.ts).
 Required modules are also declared above allowing their type information to be used.
 The file ./exports.ts manually defines the `module` and sets `module.exports` to the `facet` function.
 The file build order is specified in ../compile-tsc (this file is first, exports.ts is last).
 Please look at compile-tsc and exports.ts to get the full picture.
 Also checkout ../build/facet.js to understand what it ends up looking as.

 Footnotes:
 [1] If I am wrong and there is a better way to do this PLEASE let me know; I will buy you a beer - VO
 [2] http://www.typescriptlang.org/Handbook#modules-pitfalls-of-modules

 */

var HigherObject = <HigherObject.Base>require("higher-object");
var q = <typeof Q>require("q");
var Q_delete_me_ = q;
var async = <Async>require("async");
var chronology = <typeof Chronology>require("chronology");
var Chronology_delete_me_ = chronology;

// --------------------------------------------------------

interface Lookup<T> {
  [key: string]: T;
}

interface Parser {
  parse: (str: string) => any;
}

interface Dummy {}

// --------------------------------------------------------

var dummyObject: Dummy = {};

var objectHasOwnProperty = Object.prototype.hasOwnProperty;
function hasOwnProperty(obj: any, key: string): boolean {
  return objectHasOwnProperty.call(obj, key);
}

function shallowCopy(obj: Lookup<any>): Lookup<any> {
  var newObj: any = {};
  for (var k in obj) {
    if (!hasOwnProperty(obj, k)) continue;
    newObj[k] = obj[k];
  }
  return newObj;
}


module Core {
  export var expressionParser = <Parser>require("../parser/expression");

  export var isInstanceOf = HigherObject.isInstanceOf;
  export var isHigherObject = HigherObject.isHigherObject;

  export import ImmutableClass = HigherObject.ImmutableClass;
  export import ImmutableInstance = HigherObject.ImmutableInstance;

  export import Timezone = Chronology.Timezone;
  export import Duration = Chronology.Duration;

  export interface Datum {
    [attribute: string]: any;
    $def?: Lookup<any>;
  }
}

module Legacy {
  export var filterParser = <Parser>require("../parser/filter");
  export var applyParser = <Parser>require("../parser/apply");

  export var isInstanceOf = HigherObject.isInstanceOf;

  export import ImmutableClass = HigherObject.ImmutableClass;
  export import ImmutableInstance = HigherObject.ImmutableInstance;

  export import Timezone = Chronology.Timezone;
  export import Duration = Chronology.Duration;

  export interface Datum {
    [attribute: string]: any;
  }
}
