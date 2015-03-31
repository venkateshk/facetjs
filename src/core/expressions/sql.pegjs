{
  var base = { op: 'literal', value: [{}] };
  var dataRef = { op: 'ref', name: 'data' };

  function parentify(ref) {
    return { op: 'ref', name: '^' + ref.name };
  }

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
        if (label) error('already have a label');
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

  function handleQuery(columns, from, where, groupBy, having, orderBy, limit) {
    from = from || dataRef;

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
            op: 'actions',
            operand: parentify(from),
            actions: [{
              action: 'filter',
              expression: { op: 'is', lhs: groupBy, rhs: { op: 'ref', name: '^' + extract.label }}
            }]
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
    if (having) {
      actions.push(having);
    }
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
}

start
  = _ query:SQLQuery _ { return query; }

SQLQuery
  = SelectToken __ columns:Columns from:From where:Where? groupBy:GroupBy? having:Having? orderBy:OrderBy? limit:Limit?
    { return handleQuery(columns, from, where, groupBy, having, orderBy, limit); }

SQLSubQuery
  = SelectToken __ columns:Columns groupBy:GroupBy? having:Having? orderBy:OrderBy? limit:Limit?
    { return handleQuery(columns, null, null, groupBy, having, orderBy, limit); }

Columns
  = head:Column? tail:(_ "," _ Column)*
    {
      if (!head) return [];
      return [head].concat(tail.map(function(t) { return t[3] }));
    }

Column
  = ex:Expression as:As?
    { return { action: 'apply', name: as || 'noName', expression: ex }; }

As
  = __ AsToken __ name:String { return name; }

From
  = __ FromToken __ table:Ref
    { return table; }

Where
  = __ WhereToken __ filter:Expression
    { return filter; }

GroupBy
  = __ GroupToken __ ByToken __ groupBy:Expression
    { return groupBy; }

Having
  = __ HavingToken __ having:Expression
    { return { action: 'filter', expression: having }; }

OrderBy
  = __ OrderToken __ ByToken __ orderBy:Expression direction:Direction?
    { return { action: 'sort', expression: orderBy, direction: direction || 'ascending' }; }

Direction
  = __ dir:(AscToken / DescToken) { return dir; }

Limit
  = __ "LIMIT"i __ limit:Number
    { return { action: 'limit', limit: limit }; }

Expression
  = BinaryExpression
  / AdditiveExpression

BinaryExpression
  = lhs:AdditiveExpression _ op:BinaryOp _ rhs:Expression
    {
      if (op === 'isnt') {
        return { op: 'not', operand: { op: 'is', lhs: lhs, rhs: rhs }};
      } else {
        return { op: op, lhs: lhs, rhs: rhs };
      }
    }

BinaryOp
  = "="  { return 'is'; }
  / "<>" { return 'isnt'; }
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
  = CountToken "()"
    { return { op: 'aggregate', fn: 'count', operand: dataRef }; }
  / fn:AggregateFn "(" _ ex:Expression _ ")"
    { return { op: 'aggregate', fn: fn, operand: dataRef, attribute: ex }; }

AggregateFn
  = SumToken / AvgToken / MinToken / MaxToken

Ref
  = "`" name:RefName "`"
    { return { op: "ref", name: name }; }

Literal
  = number:Number { return { op: "literal", value: number }; }
  / string:String { return { op: "literal", value: string }; }
  / v:(NullToken / TrueToken / FalseToken) { return { op: "literal", value: v }; }

String "String"
  = "'" chars:NotSQuote "'" { return chars; }
  / "'" chars:NotSQuote { error("Unmatched single quote"); }
  / '"' chars:NotDQuote '"' { return chars; }
  / '"' chars:NotDQuote { error("Unmatched double quote"); }

/* Tokens */

NullToken     = "NULL"i     !IdentifierPart { return null; }
TrueToken     = "TRUE"i     !IdentifierPart { return true; }
FalseToken    = "FALSE"i    !IdentifierPart { return false; }

SelectToken   = "SELECT"i   !IdentifierPart
ShowToken     = "SHOW"i     !IdentifierPart
DropToken     = "DROP"i     !IdentifierPart
UpdateToken   = "UPDATE"i   !IdentifierPart
CreateToken   = "CREATE"i   !IdentifierPart
DeleteToken   = "DELETE"i   !IdentifierPart
InsertToken   = "INSERT"i   !IdentifierPart
ReplaceToken  = "REPLACE"i  !IdentifierPart
ExplainToken  = "EXPLAIN"i  !IdentifierPart

FromToken     = "FROM"i     !IdentifierPart
IntoToken     = "INTO"i     !IdentifierPart
SetToken      = "SET"i      !IdentifierPart

AsToken       = "AS"i       !IdentifierPart
TableToken    = "TABLE"i    !IdentifierPart

OnToken       = "ON"i       !IdentifierPart
LeftToken     = "LEFT"i     !IdentifierPart
InnerToken    = "INNER"i    !IdentifierPart
JoinToken     = "JOIN"i     !IdentifierPart
UnionToken    = "UNION"i    !IdentifierPart
ValuesToken   = "VALUES"i   !IdentifierPart

ExistsToken   = "EXISTS"i   !IdentifierPart

WhereToken    = "WHERE"i    !IdentifierPart

GroupToken    = "GROUP"i    !IdentifierPart
ByToken       = "BY"i       !IdentifierPart
OrderToken    = "ORDER"i    !IdentifierPart
HavingToken   = "HAVING"i   !IdentifierPart

LimitToken    = "LIMIT"i    !IdentifierPart

AscToken      = "ASC"i      !IdentifierPart { return 'ascending';  }
DescToken     = "DESC"i     !IdentifierPart { return 'descending'; }

AllToken      = "ALL"i      !IdentifierPart
DistinctToken = "DISTINCT"i !IdentifierPart

BetweenToken  = "BETWEEN"i  !IdentifierPart
InToken       = "IN"i       !IdentifierPart
IsToken       = "IS"i       !IdentifierPart
LikeToken     = "LIKE"i     !IdentifierPart
ContainsToken = "CONTAINS"i !IdentifierPart

NotToken      = "NOT"i      !IdentifierPart
AndToken      = "AND"i      !IdentifierPart
OrToken       = "OR"i       !IdentifierPart

CountToken    = "COUNT"i    !IdentifierPart { return 'count'; }
SumToken      = "SUM"i      !IdentifierPart { return 'sum';   }
AvgToken      = "AVG"i      !IdentifierPart { return 'average'; }
MinToken      = "MIN"i      !IdentifierPart { return 'min';   }
MaxToken      = "MAX"i      !IdentifierPart { return 'max';   }

IdentifierPart = [A-Za-z_]

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

Name "Name"
  = $([a-z0-9A-Z_]+)

RefName "RefName"
  = $("^"* [a-z0-9A-Z_]+)

NotSQuote "NotSQuote"
  = $([^']*)

NotDQuote "NotDQuote"
  = $([^"]*)

_ "Whitespace"
  = $ ([ \t\r\n] / SingleLineComment)*

__ "Mandatory Whitespace"
  = $ ([ \t\r\n] / SingleLineComment)+

SingleLineComment
  = "--" (!LineTerminator .)*

LineTerminator
  = [\n\r]
