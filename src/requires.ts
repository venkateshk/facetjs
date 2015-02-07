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
 Because it relies on require in node it will not work if there are two files that are interdependent

 example:  dataset.split(...) => Set  and  set.label('blah') => Dataset

 Writing the entire program as one file would suck. External modules are therefor a no go.

 Internal modules have a nicer syntax and can be split across files and then compiled into one file.
 The modules are "meant" for the web environment where their external dependencies just live in the global scope.
 The only hard bit is using traditional `require` for loading other (3rd party) modules


 Footnotes:
 [1] If I am wrong and there is a better way to do this PLEASE let me know; I will buy you a beer - VO
 [2] http://www.typescriptlang.org/Handbook#modules-pitfalls-of-modules

 */

var HigherObject = <HigherObject.Base>require("higher-object");


