{
  var base = { op: 'literal', value: [{}] };
  var dataRef = { op: 'ref', name: 'data' };
  var dateRegExp = /^\d\d\d\d-\d\d-\d\d(?:T(?:\d\d)?(?::\d\d)?(?::\d\d)?(?:.\d\d\d)?)?Z?$/;

  // See here: https://www.drupal.org/node/141051
  var reservedWords = {
    ALL: 1, AND: 1,  AS: 1, ASC: 1, AVG: 1,
    BETWEEN: 1, BY: 1,
    CONTAINS: 1, CREATE: 1,
    DELETE: 1, DESC: 1, DISTINCT: 1, DROP: 1,
    EXISTS: 1, EXPLAIN: 1,
    FALSE: 1, FROM: 1,
    GROUP: 1,
    HAVING: 1,
    IN: 1, INNER: 1,  INSERT: 1, INTO: 1, IS: 1,
    JOIN: 1,
    LEFT: 1, LIKE: 1, LIMIT: 1,
    MAX: 1, MIN: 1,
    NOT: 1, NULL: 1, NUMBER_BUCKET: 1,
    ON: 1, OR: 1, ORDER: 1,
    REPLACE: 1,
    SELECT: 1, SET: 1, SHOW: 1, SUM: 1,
    TABLE: 1, TIME_BUCKET: 1, TRUE: 1,
    UNION: 1, UPDATE: 1,
    VALUES: 1,
    WHERE: 1
  }

  var objectHasOwnProperty = Object.prototype.hasOwnProperty;
  function reserved(str) {
    return objectHasOwnProperty.call(reservedWords, str.toUpperCase());
  }

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
    if (!columns) error('Can not have empty column list');
    from = from || dataRef;

    // Support for not having a group by clause is there are aggregates in the columns
    // A redneck check for aggregate columns is the same as having "GROUP BY 1"
    if (!groupBy && JSON.stringify(columns).indexOf('"op":"aggregate"') !== -1) {
      groupBy = { op: 'literal', value: 1 };
    }

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

  function naryExpressionFactory(op, head, tail) {
    if (!tail.length) return head;
    return {
      op: op,
      operands: [head].concat(tail.map(function(t) { return t[3]; }))
    };
  }

  function naryExpressionWithAltFactory(op, head, tail, altToken, altOp) {
    if (!tail.length) return head;
    return {
      op: op,
      operands: [head].concat(tail.map(function(t) {
        return t[1] === altToken ? { op: 'negate', operand: t[3] } : t[3];
      }))
    };
  }
}

start
  = _ query:SQLQuery _ { return query; }

SQLQuery
  = SelectToken columns:Columns? from:FromClause? where:WhereClause? groupBy:GroupByClause? having:HavingClause? orderBy:OrderByClause? limit:LimitClause?
    { return handleQuery(columns, from, where, groupBy, having, orderBy, limit); }

SQLSubQuery
  = SelectToken columns:Columns? groupBy:GroupByClause having:HavingClause? orderBy:OrderByClause? limit:LimitClause?
    { return handleQuery(columns, null, null, groupBy, having, orderBy, limit); }

Columns
  = __ head:Column tail:(_ "," _ Column)*
    { return [head].concat(tail.map(function(t) { return t[3] })); }

Column
  = ex:Expression as:As?
    {
      return {
        action: 'apply',
        name: as || text().toLowerCase().replace(/^\W+|\W+$/g, '').replace(/\W+/g, '_'),
        expression: ex
      };
    }

As
  = __ AsToken __ name:(String / Ref) { return name; }

FromClause
  = __ FromToken __ table:RefExpression
    { return table; }

WhereClause
  = __ WhereToken __ filter:Expression
    { return filter; }

GroupByClause
  = __ GroupToken __ ByToken __ groupBy:Expression
    { return groupBy; }

HavingClause
  = __ HavingToken __ having:Expression
    { return { action: 'filter', expression: having }; }

OrderByClause
  = __ OrderToken __ ByToken __ orderBy:Expression direction:Direction?
    { return { action: 'sort', expression: orderBy, direction: direction || 'ascending' }; }

Direction
  = __ dir:(AscToken / DescToken) { return dir; }

LimitClause
  = __ LimitToken __ limit:Number
    { return { action: 'limit', limit: limit }; }

/*
Expressions are filed in below in acceding priority order

  Or (OR)
  And (AND)
  Not (NOT)
  Comparison (=, <, >, <=, >=, <>, !=, IS, LIKE, BETWEEN, IN, CONTAINS)
  Additive (+, -)
  Multiplicative (*), Division (/)
  identity (+), negation (-)
*/

Expression = OrExpression

OrExpression
  = head:AndExpression tail:(_ OrToken _ AndExpression)*
    { return naryExpressionFactory('or', head, tail); }

AndExpression
  = head:NotExpression tail:(_ AndToken _ NotExpression)*
    { return naryExpressionFactory('and', head, tail); }

NotExpression
  = NotToken __ ex:ComparisonExpression { return { op: 'not', operand: ex }; }
  / ComparisonExpression

ComparisonExpression
  = lhs:AdditiveExpression rest:(_ ComparisonOp _ AdditiveExpression)?
    {
      if (!rest) return lhs;
      var op = rest[1];
      var rhs = rest[3];
      if (op === 'isnt') {
        return { op: 'not', operand: { op: 'is', lhs: lhs, rhs: rhs }};
      } else {
        return { op: op, lhs: lhs, rhs: rhs };
      }
    }

ComparisonOp
  = "="  { return 'is'; }
  / "<>" { return 'isnt'; }
  / "!=" { return 'isnt'; }
  / "in" { return 'in'; }
  / "<=" { return 'lessThanOrEqual'; }
  / ">=" { return 'greaterThanOrEqual'; }
  / "<"  { return 'lessThan'; }
  / ">"  { return 'greaterThan'; }

AdditiveExpression
  = head:MultiplicativeExpression tail:(_ AdditiveOp _ MultiplicativeExpression)*
    { return naryExpressionFactory('add', head, tail, '-', 'negate'); }

AdditiveOp = [+-]

MultiplicativeExpression
  = head:BasicExpression tail:(_ MultiplicativeOp _ BasicExpression)*
    { return naryExpressionFactory('multiply', head, tail, '/', 'reciprocate'); }

MultiplicativeOp = [*/]

BasicExpression
  = LiteralExpression
  / AggregateExpression
  / FunctionCallExpression
  / "(" _ ex:Expression _ ")" { return ex; }
  / "(" _ subQuery:SQLSubQuery _ ")" { return subQuery; }
  / RefExpression

AggregateExpression
  = CountToken "()"
    { return { op: 'aggregate', fn: 'count', operand: dataRef }; }
  / fn:AggregateFn "(" _ ex:Expression _ ")"
    { return { op: 'aggregate', fn: fn, operand: dataRef, attribute: ex }; }

AggregateFn
  = SumToken / AvgToken / MinToken / MaxToken

FunctionCallExpression
  = TimeBucketToken "(" _ operand:Expression _ "," _ duration:Name _ "," _ timezone:String ")"
    { return { op: 'timeBucket', operand: operand, duration: duration, timezone: timezone }; }
  / NumberBucketToken "(" _ operand:Expression _ "," _ size:Number _ "," _ offset:Number ")"
    { return { op: 'numberBucket', operand: operand, size: size, offset: offset }; }

RefExpression
  = ref:Ref { return { op: "ref", name: ref }; }

LiteralExpression
  = number:Number { return { op: "literal", value: number }; }
  / string:String
    {
      if (dateRegExp.test(string)) {
        var date = new Date(string);
        if (!isNaN(date)) {
          return { op: "literal", value: date };
        } else {
          return { op: "literal", value: string };
        }
      } else {
        return { op: "literal", value: string };
      }
    }
  / v:(NullToken / TrueToken / FalseToken) { return { op: "literal", value: v }; }

Ref
  = name:RefName !{ return reserved(name); }
    { return name }
  / "`" name:RefName "`"
    { return name }

String "String"
  = "'" chars:NotSQuote "'" { return chars; }
  / "'" chars:NotSQuote { error("Unmatched single quote"); }
  / '"' chars:NotDQuote '"' { return chars; }
  / '"' chars:NotDQuote { error("Unmatched double quote"); }

/* Tokens */

NullToken         = "NULL"i          !IdentifierPart { return null; }
TrueToken         = "TRUE"i          !IdentifierPart { return true; }
FalseToken        = "FALSE"i         !IdentifierPart { return false; }

SelectToken       = "SELECT"i        !IdentifierPart
FromToken         = "FROM"i          !IdentifierPart
AsToken           = "AS"i            !IdentifierPart
OnToken           = "ON"i            !IdentifierPart
LeftToken         = "LEFT"i          !IdentifierPart
InnerToken        = "INNER"i         !IdentifierPart
JoinToken         = "JOIN"i          !IdentifierPart
UnionToken        = "UNION"i         !IdentifierPart
WhereToken        = "WHERE"i         !IdentifierPart
GroupToken        = "GROUP"i         !IdentifierPart
ByToken           = "BY"i            !IdentifierPart
OrderToken        = "ORDER"i         !IdentifierPart
HavingToken       = "HAVING"i        !IdentifierPart
LimitToken        = "LIMIT"i         !IdentifierPart

AscToken          = "ASC"i           !IdentifierPart { return 'ascending';  }
DescToken         = "DESC"i          !IdentifierPart { return 'descending'; }

BetweenToken      = "BETWEEN"i       !IdentifierPart
InToken           = "IN"i            !IdentifierPart
IsToken           = "IS"i            !IdentifierPart
LikeToken         = "LIKE"i          !IdentifierPart
ContainsToken     = "CONTAINS"i      !IdentifierPart

NotToken          = "NOT"i           !IdentifierPart
AndToken          = "AND"i           !IdentifierPart
OrToken           = "OR"i            !IdentifierPart

CountToken        = "COUNT"i         !IdentifierPart { return 'count'; }
SumToken          = "SUM"i           !IdentifierPart { return 'sum'; }
AvgToken          = "AVG"i           !IdentifierPart { return 'average'; }
MinToken          = "MIN"i           !IdentifierPart { return 'min'; }
MaxToken          = "MAX"i           !IdentifierPart { return 'max'; }

TimeBucketToken   = "TIME_BUCKET"i   !IdentifierPart
NumberBucketToken = "NUMBER_BUCKET"i !IdentifierPart

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
  = $([a-zA-Z_] [a-z0-9A-Z_]*)

RefName "RefName"
  = $("^"* Name)

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
