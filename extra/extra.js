var fs = require('fs');

var defFilename = './build/facet.d.ts';
var newDefFilename = './build/facetjs.d.ts';
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
defData = defData.replace(/declare var module: \{\s*exports: any;\s*};\n/, '');

// Ensure it was deleted
if (defData.indexOf('declare var module') !== -1) {
  throw new Error("failed to delete require declaration");
}

defData += '\n';
defData = defData.replace(/declare module Facet\.Legacy \{[\s\S]+?\n}\n/g, '');

// Ensure it was deleted
if (defData.indexOf('declare module Facet.Legacy') !== -1) {
  throw new Error("failed to delete Facet.Legacy");
}

defData = defData.replace(/}\ndeclare module Facet \{\n/g, '');

// remove protected
defData = defData.replace(/ +protected [^\n]+\n/g, '');

// remove _delete_me_
defData = defData.replace(/[^\n]+_delete_me_[^\n]+\n/g, '');

// Make explicit node module
defData = defData.replace(/declare module Facet/, 'declare module "facetjs"');

// Delete the _delete_me_
jsData = jsData.replace(/_delete_me_/g, '');

fs.writeFileSync(newDefFilename, defData, 'utf8');
fs.writeFileSync(jsFilename, jsData, 'utf8');
