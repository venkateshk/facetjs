start
  = Expression

Expression
  = _ ex:AdditiveExpression _ { return ex; }

AdditiveExpression
  = head:MultiplicativeExpression tail:(_ [+-] _ MultiplicativeExpression)*
    {
      if (!tail.length) return head;
      var operands = [head];
      for (var i = 0; i < tail.length; i++) {
        if (tail[i][1] === '+') {
          operands.push(tail[i][3]);
        } else {
          operands.push({ op: 'negate', operand: tail[i][3] });
        }
      }
      return { op: 'add', operands: operands };
    }

MultiplicativeExpression
  = head:Factor tail:(_ [*/] _ Factor)*
    {
      if (!tail.length) return head;
      var operands = [head];
      for (var i = 0; i < tail.length; i++) {
        if (tail[i][1] === '*') {
          operands.push(tail[i][3]);
        } else {
          operands.push({ op: 'reciprocate', operand: tail[i][3] });
        }
      }
      return { op: 'multiply', operands: operands };
    }

Factor
  = "(" ex:Expression ")" { return ex; }
  / Aggregate
  / Literal
  / Variable


Aggregate
  = ex:Variable "." fn:AggregateFn "(" _ agg:Expression? _ ")"
    { 
      var res = { op: "aggregate", fn: fn, operand: ex };
      if (agg) res.aggregate = agg;
      return res; 
    }

Variable
  = "$" name:Name { return { op: "ref", name: name }; }

Literal
  = number:Number { return { op: "literal", value: number }; }
  / string:String { return { op: "literal", value: string }; }

AggregateFn "Aggregate Function"
  = "count" / "sum" / "max" / "min" / "average" / "uniqueCount"


String "String"
  = "'" chars:NotSQuote "'" { return chars; }
  / "'" chars:NotSQuote { throw new Error("Unmatched single quote")}
  / '"' chars:NotDQuote '"' { return chars; }
  / '"' chars:NotDQuote { throw new Error("Unmatched double quote")}


/* Numbers */

Number "Number"
  = n: $(Int Frac? Exp?) { return parseFloat(n); }

Int
  = $("-"? [1-9] Digits)
  / $("-"? Digit)

Frac
  = $("." Digits)

Exp
  = $([eE] [+-]? Digits)

Digits
  = $ Digit+

Digit
  = [0-9]


/* Extra */

Name "Name"
  = $([a-z0-9A-Z_]+)

NotSQuote "NotSQuote"
  = $([^']+)

NotDQuote "NotDQuote"
  = $([^"]+)

_ "Whitespace"
  = [ \t\r\n]*
