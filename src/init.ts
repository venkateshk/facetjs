/// <reference path="../definitions/require.d.ts" />
/// <reference path="../definitions/higher-object.d.ts" />
/// <reference path="../typings/q/Q.d.ts" />

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

 A note about TSD type definitions:
 The output of require('...') calls must be typecast to the correct type. The problem is that you can not typecast
 to a module type, only to an interface or class. A lot of modules are (incorrectly?) typed to have all their base
 functions on the module and not in some interface.
 If you look at the D3 example in the TS handbook[2] you will see that there is a type called `Base` and that type
 allows them to decade a `var d3`. Some modules do not have that and so (for now) I will modify their type definitions
 and put them in the ../definitions directory.

 Footnotes:
 [1] If I am wrong and there is a better way to do this PLEASE let me know; I will buy you a beer - VO
 [2] http://www.typescriptlang.org/Handbook#modules-pitfalls-of-modules

 */

var HigherObject = <HigherObject.Base>require("higher-object");
//var Q = require("q");

module Core {
  export interface Lookup<T> {
    [key: string]: T;
  }

  export interface Dummy {}

  export var dummyObject: Dummy = {};

  export var isInstanceOf = HigherObject.isInstanceOf;

  export import ImmutableClass = HigherObject.ImmutableClass;
  export import ImmutableInstance = HigherObject.ImmutableInstance;

  export interface Datum {
    [attribute: string]: any;
  }
}
