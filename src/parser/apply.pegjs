start
  = NamedApply
  / Apply

Apply
  = _ apply:AdditiveArithmetic _ { return apply; }

NamedApply
  = _ name:Name _ "<-" _ apply:AdditiveArithmetic _
    {
      var namedApply = { name: name };
      for (var k in apply) { namedApply[k] = apply[k] }
      return namedApply;
    }

Name "Name"
  = $([a-z0-9A-Z_]+)

NotTick "NotTick"
  = $([^`]+)

AdditiveArithmetic
  = head:MultiplicativeArithmetic tail:(_ [+-] _ MultiplicativeArithmetic)*
    {
      var lookup = { '+': 'add', "-": 'subtract' };
      var result = head;
      for (var i = 0; i < tail.length; i++) {
        result = {
          arithmetic: lookup[tail[i][1]],
          operands: [result, tail[i][3]]
        };
      }
      return result;
    }

MultiplicativeArithmetic
  = head:Factor tail:(_ [*/] _ Factor)*
    {
      var lookup = { "*": 'multiply', "/": 'divide' };
      var result = head;
      for (var i = 0; i < tail.length; i++) {
        result = {
          arithmetic: lookup[tail[i][1]],
          operands: [result, tail[i][3]]
        };
      }
      return result;
    }

Factor
  = "(" _ apply:AdditiveArithmetic _ ")" { return apply; }
  / Aggregate

Aggregate "Aggregate"
  = number:Number
    { return { aggregate: "constant", value: number }; }
  / aggregate:AggregateFn0 "(" _ ")"
    { return { aggregate: aggregate }; }
  / aggregate:AggregateFn1 "(" attribute:Attribute ")"
    { return { aggregate: aggregate, attribute:attribute }; }

AggregateFn0 "Aggregare Function"
  = "count"

AggregateFn1 "Aggregare Function"
  = "sum"
  / "max"
  / "min"
  / "average"
  / "uniqueCount"

Attribute "Attribute"
  = "`" chars:NotTick "`" { return chars; }
  / chars:Name
  / "`" chars:NotTick { throw new Error("Unmatched tickmark")}


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


_ "Whitespace"
  = [ \t\r\n]*


