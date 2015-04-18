{// starts with function(facet)
var $ = facet.$;
var Expression = facet.Expression;

var possibleCalls = {
  'is': 1,
  'in': 1,
  'lessThanOrEqual': 1,
  'greaterThanOrEqual': 1,
  'lessThan': 1,
  'greaterThan': 1,
  'add': 1,
  'multiply': 1,
  'subtract': 1,
  'divide': 1,
  'not': 1,
  'negate': 1,
  'reciprocate': 1,
  'match': 1,
  'numberBucket': 1,
  'timeBucket': 1,
  'substr': 1,
  'timePart': 1,
  'filter': 1,
  'def': 1,
  'apply': 1,
  'sort': 1,
  'limit': 1,
  'count': 1,
  'sum': 1,
  'max': 1,
  'min': 1,
  'average': 1,
  'uniqueCount': 1,
  'group': 1,
  'label': 1,
  'split': 1
};

}// Start grammar

start
  = _ ex:Expression _ { return ex; }

Expression
  = BinaryExpression
  / AdditiveExpression
  / CallChainExpression

CallChainExpression
  = lhs:Leaf tail:(_ "." _ CallFn "(" _ Params? _ ")")+
    {
      var operand = lhs;
      for (var i = 0, n = tail.length; i < n; i++) {
        var part = tail[i];
        var op = part[3];
        if (!possibleCalls[op]) error('no such call: ' + op);
        var params = part[6] || [];
        operand = operand[op].apply(operand, params);
      }
      return operand;
    }

Params
  = head:Param tail:(_ "," _ Param)*
    { return [head].concat(tail.map(function(t) { return t[3] })); }

Param
  = Number / Name / String / Expression

BinaryExpression
  = lhs:AdditiveExpression _ op:BinaryOp _ rhs:Expression
    { return lhs[op](rhs); }

BinaryOp
  = "="  { return 'is'; }
  / "in" { return 'in'; }
  / "<=" { return 'lessThanOrEqual'; }
  / ">=" { return 'greaterThanOrEqual'; }
  / "<"  { return 'lessThan'; }
  / ">"  { return 'greaterThan'; }

AdditiveExpression
  = head:MultiplicativeExpression tail:(_ [+-] _ MultiplicativeExpression)*
    {
      if (!tail.length) return head;
      var operands = [];
      for (var i = 0; i < tail.length; i++) {
        if (tail[i][1] === '+') {
          operands.push(tail[i][3]);
        } else {
          operands.push(tail[i][3].negate());
        }
      }
      return head.add.apply(head, operands);
    }

MultiplicativeExpression
  = head:Factor tail:(_ [*/] _ Factor)*
    {
      if (!tail.length) return head;
      var operands = [];
      for (var i = 0; i < tail.length; i++) {
        if (tail[i][1] === '*') {
          operands.push(tail[i][3]);
        } else {
          operands.push(tail[i][3].reciprocate());
        }
      }
      return head.multiply.apply(head, operands);
    }

Factor
  = CallChainExpression
  / "(" _ ex:Expression _ ")" { return ex; }
  / Literal
  / Ref

Leaf
  = "(" _ ex:Expression _ ")" { return ex; }
  / Literal
  / Ref
  / "$()" { return $(); }

Ref
  = "$" name:RefName ":" type:TypeName
    { return $(name + ':' + type); }
  / "$" name:RefName
    { return $(name); }

Literal
  = value:Number { return Expression.fromJS({ op: "literal", value: value }); }
  / value:String { return Expression.fromJS({ op: "literal", value: value }); }

String "String"
  = "'" chars:NotSQuote "'" { return chars; }
  / "'" chars:NotSQuote { error("Unmatched single quote"); }
  / '"' chars:NotDQuote '"' { return chars; }
  / '"' chars:NotDQuote { error("Unmatched double quote"); }


/* Numbers */

Number "Number"
  = n: $(Int Fraction? Exp?) { return parseFloat(n); }

Int
  = $("-"? [1-9] Digits)
  / $("-"? Digit)

Fraction
  = $("." Digits)

Exp
  = $("e"i [+-]? Digits)

Digits
  = $ Digit+

Digit
  = [0-9]


/* Extra */

CallFn "CallFn"
  = $([a-zA-Z]+)

Name "Name"
  = $([a-z0-9A-Z_]+)

RefName "RefName"
  = $("^"* Name)

TypeName "TypeName"
  = $([A-Z_/]+)

NotSQuote "NotSQuote"
  = $([^']*)

NotDQuote "NotDQuote"
  = $([^"]*)

_ "Whitespace"
  = $([ \t\r\n]*)
