{
  var base = { op: 'literal', value: [{}] };
  var dataRef = { op: 'ref', name: 'data' };

  function equals(a, b) {
    aKeys = Object.keys(a).sort();
    bKeys = Object.keys(b).sort();
    if (String(aKeys) !== String(bKeys)) return false;
    for (var i = 0; i < aKeys.length; i++) {
      var key = aKeys[i];
      var va = a[key];
      var vb = b[key];
      var tva = typeof va;
      if (tva !== typeof vb) return false;
      if (tva === 'object') {
        if (!equals(va, vb)) return false;
      } else {
        if (va !== vb) return false;
      }
    }
    return true;
  }

  function extractGroupByColumn(columns, groupBy) {
    var label = null;
    var applyColumns = [];
    for (var i = 0; i < columns.length; i++) {
      var column = columns[i];
      if (equals(groupBy, column.expression)) {
        if (label) throw new Error('already have a label');
        label = column.name;
      } else {
        applyColumns.push(column);
      }
    }
    if (!label) label = 'split';
    return {
      label: label,
      applyColumns: applyColumns
    };
  }
}

start
  = _ query:SQLQuery _ { return query; }

SQLQuery
  = "SELECT" __ columns:Columns from:From where:Where? groupBy:GroupBy? orderBy:OrderBy? limit:Limit?
    {
      var operand = null;
      var groupByDef = null;
      if (!groupBy) {
        operand = dataRef;
      } else {
        if (groupBy.op === 'literal') {
          operand = base;
        } else {
          var extract = extractGroupByColumn(columns, groupBy);
          columns = extract.applyColumns;
          operand = {
            op: 'label',
            name: extract.label,
            operand: {
              op: 'aggregate',
              operand: dataRef,
              fn: 'group',
              attribute: groupBy
            }
          };
          groupByDef = {
            action: 'def',
            name: 'data',
            expression: {
              op: 'is',
              lhs: groupBy,
              rhs: { op: 'ref', name: '^' + extract.label }
            }
          }
        }
      }

      var dataFrom = from;
      if (where) {
        dataFrom = {
          op: 'actions',
          operand: dataFrom,
          actions: [{
            action: 'filter',
            expression: where
          }]
        };
      }

      var actions = [];
      if (groupByDef) {
        actions.push(groupByDef);
      } else {
        actions.push({
          action: 'def',
          name: 'data',
          expression: dataFrom
        });
      }
      actions = actions.concat(columns);
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

SQLSubQuery
  = "SELECT" __ columns:Columns groupBy:GroupBy? orderBy:OrderBy? limit:Limit?
    {
      var operand = null;
      var groupByDef = null;
      if (!groupBy) {
        operand = dataRef;
      } else {
        if (groupBy.op === 'literal') {
          operand = base;
        } else {
          var extract = extractGroupByColumn(columns, groupBy);
          columns = extract.applyColumns;
          operand = {
            op: 'label',
            name: extract.label,
            operand: {
              op: 'aggregate',
              operand: base,
              fn: 'group',
              attribute: groupBy
            }
          };
          groupByDef = {
            action: 'def',
            name: 'data',
            expression: {
              op: 'is',
              lhs: groupBy,
              rhs: { op: 'ref', name: '^' + extract.label }
            }
          }
        }
      }

      var actions = [];
      if (groupByDef) {
        actions.push(groupByDef);
      } else {
        actions.push({
          action: 'def',
          name: 'data',
          expression: dataRef
        });
      }
      actions = actions.concat(columns);
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
  = __ "FROM" __ table:Ref
    { return table; }

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
        direction: direction || 'ascending'
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
  / "(" _ subQuery:SQLSubQuery _ ")" { return subQuery; }
  / Literal
  / Ref
  / Aggregate

Aggregate
  = "COUNT()"
    { return { op: 'aggregate', fn: 'count', operand: dataRef }; }
  / "SUM(" _ ex:Expression _ ")"
    { return { op: 'aggregate', fn: 'sum', operand: dataRef, attribute: ex }; }

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
