var fs = require('fs');

var defFilename = './build/facet.d.ts';
var jsFilename = './build/facet.js';
try {
  var defData = fs.readFileSync(defFilename, 'utf8');
  var jsData = fs.readFileSync(jsFilename, 'utf8');
} catch (e) {
  process.exit(0);
}

// Delete:
// declare function require(file: string): any;
defData = defData.replace('declare function require(file: string): any;\n', '');

// Ensure it was deleted
if (defData.indexOf('declare function require') !== -1) {
  throw new Error("failed to delete require declaration");
}

// Delete:
// declare var module: {
//   exports: any;
// };
defData = defData.replace(/declare var module: \{\s*exports: any;\s*\};\n/, '');

// Ensure it was deleted
if (defData.indexOf('declare var module') !== -1) {
  throw new Error("failed to delete require declaration");
}

var defLines = defData.split('\n');


/*
// Add the extra export code
defData += [
  '',
  'interface Facet {',
  '    (input?: any): Core.Expression;',
  '    core: typeof Core;',
  '    legacy: typeof Legacy;',
  '}',
  'declare var facet: Facet;',
  'declare module "facetjs" {',
  '    export = facet;',
  '}'
].join('\n');
*/

// Delete the _delete_me_
jsData = jsData.replace(/_delete_me_/g, '');

fs.writeFileSync(defFilename, defData, 'utf8');
fs.writeFileSync(jsFilename, jsData, 'utf8');
