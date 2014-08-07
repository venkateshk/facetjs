start
  = AndFilter

AndFilter
  = _ left:OrFilter _ "and" _ right:AndFilter _ {
    if (right.type === "and") {
      return {
        type: "and",
        filters: [left].concat(right.filters)
      };
    } else {
      return {
        type: "and",
        filters: [left].concat(right)
      };
    }
  }
  / OrFilter

OrFilter
  = _ left:BasicFilter _ "or" _ right:OrFilter _ {
    if (right.type === "or") {
      return {
        type: "or",
        filters: [left].concat(right.filters)
      };
    } else {
      return {
        type: "or",
        filters: [left].concat(right)
      };
    }
  }
  / BasicFilter

BasicFilter
  = _ attribute:Attribute _ "in" _ values:ValueList _ {
    return {
      type: 'in',
      values: values,
      attribute: attribute
    };
  }
  / _ attribute:Attribute _ "is" _ value:Value _ {
    return {
      type: 'is',
      value: value,
      attribute: attribute
    };
  }
  / _ "not" _ primary:NotSuffix _ {
    return {
      type: 'not',
      filter: primary
    };
  }
    / _ "(" _ andFilter:AndFilter _ ")" _ { return andFilter; }

NotSuffix
  = BasicFilter
  / AndFilter

Attribute "Attribute"
  = "`" _ prim:NotTick _ "`" { return prim; }
  / $([a-zA-Z0-9_]+)

Value "Value"
  = '"' _ prim:NotQuote _ '"' { return prim; }
  / $([a-zA-Z0-9_]+)

ValueList "ValueList"
  = "(" _ body:(_ Value _ ",")* _ tail:Value _ ")" {
      return body.map(function(a) {return a[1];}).concat(tail);
    }

NotQuote "NotQuote"
  = $([^"]+)

NotTick "NotTick"
  = $([^`]+)

_ "Whitespace"
  = [ \t\n\r]*
