{
  var base = { op: 'literal', value: [{}] };
  var dataRef = { op: 'ref', name: 'data' };
}

start
  = _ q:SQLQuery _ { return q; }

SQLQuery
  = "SELECT" __ columns:Columns from:From groupBy:GroupBy? orderBy:OrderBy? limit:Limit?
    {
      var operand = null;
      if (groupBy) {
        if (groupBy.op === 'literal') {
          operand = base;
        } else {
          operand = {
            op: 'aggregate',
            operand: base,
            fn: 'group',
            attribute: groupBy
          };
        }
      } else {
        operand = dataRef;
      }

      var actions = columns.slice();
      if (orderBy) {
        actions.push(orderBy);
      }
      if (limit) {
        actions.push(limit);
      }

      return {
        op: 'actions',
        operand: operand,
        actions: actions
      };
    }

Columns
  = head:Column? tail:(_ "," _ Column)*
    {
      if (!head) return [];
      return [head].concat(tail.map(function(t) { return t[3] }));
    }

Column
  = ex:Expression as:As?
    {
      return {
        action: 'apply',
        name: as || 'no_name',
        expression: ex
      };
    }

As
  = __ "AS" __ name:String { return name; }

From
  = __ "FROM" __ table:Ref where:Where?
    { return where; }

Where
  = __ "WHERE" __ filter:Expression
    { return filter; }

GroupBy
  = __ "GROUP" __ "BY" __ groupBy:Expression
    { return groupBy; }

OrderBy
  = __ "ORDER" __ "BY" __ orderBy:Expression direction:Direction?
    { 
      return {
        action: 'sort',
        expression: orderBy,
        direction: direction
      };
    }

Direction
  = __ "ASC"  { return 'ascending'; }
  / __ "DESC" { return 'descending'; }

Limit
  = __ "LIMIT" __ limit:Number
    { 
      return {
        action: 'limit',
        limit: limit
      };
    }

Expression
  = BinaryExpression
  / AdditiveExpression

BinaryExpression
  = lhs:AdditiveExpression _ op:BinaryOp _ rhs:Expression
    { return { op: op, lhs: lhs, rhs: rhs }; }

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
  = "(" _ ex:Expression _ ")" { return ex; }
  / Literal
  / Ref
  / Aggregate

Aggregate
  = "SUM(" ex:Expression ")"
    { 
      return {
        op: 'aggregate',
        operand: dataRef,
        aggregate: ex
      };
    }

Ref
  = "`" name:RefName "`"
    { return { op: "ref", name: name }; }

Literal
  = number:Number { return { op: "literal", value: number }; }
  / string:String { return { op: "literal", value: string }; }

String "String"
  = "'" chars:NotSQuote "'" { return chars; }
  / "'" chars:NotSQuote { throw new Error("Unmatched single quote"); }
  / '"' chars:NotDQuote '"' { return chars; }
  / '"' chars:NotDQuote { throw new Error("Unmatched double quote"); }


/* Numbers */

Number "Number"
  = n: $(Int Fraction? Exp?) { return parseFloat(n); }

Int
  = $("-"? [1-9] Digits)
  / $("-"? Digit)

Fraction
  = $("." Digits)

Exp
  = $([eE] [+-]? Digits)

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
  = $("^"* [a-z0-9A-Z_]+)

TypeName "TypeName"
  = $([A-Z_/]+)

NotSQuote "NotSQuote"
  = $([^']*)

NotDQuote "NotDQuote"
  = $([^"]*)

_ "Whitespace"
  = $([ \t\r\n]*)

__ "Mandatory Whitespace"
  = $([ \t\r\n]+)
