start
  = NamedApply


NamedApply
  = _ name:Name _ "<-" _ apply:AdditiveArithmetic _
    {
      var namedApply = {name: name.join('') };
      for (var k in apply) { namedApply[k] = apply[k] }
      return namedApply;
    }

Name "Name"
  = [a-z0-9A-Z_]+

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


/* Numbers */

Number "Number"
  = int:Int frac:Frac exp:Exp { return parseFloat(int + frac + exp); }
  / int:Int frac:Frac         { return parseFloat(int + frac);       }
  / int:Int exp:Exp           { return parseFloat(int + exp);        }
  / int:Int                   { return parseFloat(int);              }

Int
  = digit19:Digit19 digits:Digits     { return digit19 + digits;       }
  / digit:Digit
  / "-" digit19:Digit19 digits:Digits { return "-" + digit19 + digits; }
  / "-" digit:Digit                   { return "-" + digit;            }

Frac
  = "." digits:Digits { return "." + digits; }

Exp
  = e:E digits:Digits { return e + digits; }

Digits
  = digits:Digit+ { return digits.join(""); }

E
  = e:[eE] sign:[+-]? { return e + sign; }

Digit
  = [0-9]

Digit19
  = [1-9]


_ "Whitespace"
  = [ \t\r\n]*


