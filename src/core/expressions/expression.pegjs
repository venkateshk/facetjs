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
  / Call
  / Literal
  / Variable


Call
  = ex:Variable "." method:Name "(" _ ")"
    { return { op: "call", object: ex, method: method }; }

Variable
  = "$" name:Name { return { op: "ref", name: name }; }

Literal
  = number:Number
    { return { op: "literal", value: number }; }

Aggregate "Aggregate"
  = aggregate:AggregateFn0 "(" _ ")"
    { return { aggregate: aggregate }; }
  / aggregate:AggregateFn1 "(" attribute:Attribute ")"
    { return { aggregate: aggregate, attribute: attribute }; }

AggregateFn0 "Aggregate Function"
  = "count"

AggregateFn1 "Aggregate Function"
  = "sum"
  / "max"
  / "min"
  / "average"
  / "uniqueCount"

Attribute "Attribute"
  = "`" chars:NotTick "`" { return chars; }
  / chars:Name
  / "`" chars:NotTick { throw new Error("Unmatched tick mark")}


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

NotTick "NotTick"
  = $([^`]+)

_ "Whitespace"
  = [ \t\r\n]*
