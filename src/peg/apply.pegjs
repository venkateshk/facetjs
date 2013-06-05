start
  = NamedApply


NamedApply
  = _ name:Name _ "<-" _ apply:AdditiveArithmetic _
    {
      var namedApply = {name: name.join('') };
      for (var k in apply) { namedApply[k] = apply[k] }
      return namedApply;
    }


AdditiveArithmetic
  = head:MultiplicativeArithmetic tail:(_ [+-] _ MultiplicativeArithmetic)*
    {
      var result = head;
      for (var i = 0; i < tail.length; i++) {
        result = {
          arithmetic: tail[i][1],
          operands: [result, tail[i][3]]
        };
      }
      return result;
    }

MultiplicativeArithmetic
  = head:Factor tail:(_ [*/] _ Factor)*
    {
      var result = head;
      for (var i = 0; i < tail.length; i++) {
        result = {
          arithmetic: tail[i][1],
          operands: [result, tail[i][3]]
        };
      }
      return result;
    }

Factor
  = "(" _ apply:AdditiveArithmetic _ ")" { return apply; }
  / Aggregate

Aggregate "Aggregate"
  = aggregate:AggregateFn "(" attribute:Attribute ")"
    { return { aggregate: aggregate, attribute:attribute }; }
  / number:Number
    { return { aggregate: "constant", value: number }; }

AggregateFn "Aggregare Function"
  = "sum"
  / "max"
  / "min"
  / "average"
  / "uniqueCount"

Attribute "Attribute"
  = "`" chars:Name "`" { return chars.join(""); }

// ToDo: make floats work
// digits:(('+' / '-')? [0-9]+ (('.' [0-9]+) / ('e' [0-9]+)))
Number
  = digits:[0-9]+
    { return parseFloat(digits.join('')) }

_ "White Space"
  = [ \t\r\n]*

Name "Name"
  = [a-z0-9A-Z_]+


//  a <- (max(`poo`)/ 103.14)
