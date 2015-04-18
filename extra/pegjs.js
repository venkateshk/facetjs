var fs = require('fs');
var PEG = require("pegjs");

var prefixToRemove = '(function() {';
var postfixToRemove = '})()';

// Expressions

var expressionGrammarFilename = './src/expressions/expression.pegjs';
var expressionGrammar = fs.readFileSync(expressionGrammarFilename, 'utf8');

var expressionParser = PEG.buildParser(expressionGrammar, {
  output: 'source',
  optimize: "speed" // or "size"
});

expressionParser = expressionParser.substring(prefixToRemove.length, expressionParser.length - postfixToRemove.length);

expressionParser = 'module.exports = function(facet) {' + expressionParser + '};\n';

fs.writeFileSync('./parser/expression.js', expressionParser, 'utf8');
