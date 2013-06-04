start
  = named

named "Naming"
  = name:[a-z]+ space* "<-" space* apply:apply
    { apply.name = name.join(''); return apply; }

apply "Apply"
  = aggregate
  / arithmetic

arithmetic "Arithmetic"
  = "(" op1:apply space* arithmetic:arithmeticFn space* op2:apply ")"
    { return { arithmetic: arithmetic, operands: [op1, op2] }; }

arithmeticFn "Arithmetic Function"
  = [+-/*]

aggregate "Aggregate"
  = aggregate:aggregateFn "(" attribute:attribute ")"
    { return { aggregate: aggregate, attribute:attribute }; }
  // digits:(('+' / '-')? [0-9]+ (('.' [0-9]+) / ('e' [0-9]+)))
  / digits:[0-9]+
    { return { aggregate: "constant", value: digits.join('') }; }

aggregateFn "Aggregare Function"
  = "sum"
  / "max"
  / "min"
  / "average"
  / "uniqueCount"

attribute "Attribute"
  = "`" chars:[a-z]+ "`" { return chars.join(""); }

space = [ \t\r\n]


//  a <- (max(`poo`)/ 103.14)
