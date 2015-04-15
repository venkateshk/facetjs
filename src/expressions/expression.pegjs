{
  var base = { op: 'literal', value: [{}] };
}

start
  = _ ex:Expression _ { return ex; }

Expression
  = BinaryExpression
  / AdditiveExpression
  / CallChainExpression

CallChainExpression
  = lhs:Leaf tail:(_ "." _ CallFn "(" _ Params? _ ")")+
    {
      var operand = lhs;
      var action;

      function addAction(action) {
        if (operand.op === 'actions') {
          operand.actions.push(action);
        } else {
          operand = { op: 'actions', operand: operand, actions: [action] };
        }
      }

      function getName(thing) {
        if (typeof thing === 'string') return thing;
        if (thing.op === 'ref') return thing.name;
        if (thing.op === 'literal') return String(thing.value);
        error("invalid parameter");
      }

      function getNumber(thing) {
        if (thing.op === 'literal') return Number(thing.value);
        error("invalid parameter (must be a number)");
      }

      for (var i = 0, n = tail.length; i < n; i++) {
        var part = tail[i];
        var op = part[3];
        var params = part[6] || [];
        switch (op) {
          case 'is':
          case 'in':
          case 'lessThanOrEqual':
          case 'greaterThanOrEqual':
          case 'lessThan':
          case 'greaterThan':
            if (params.length !== 1) error(op + ' must have 1 parameter');
            operand = { op: op, lhs: operand, rhs: params[0] };
            break;

          case 'add':
          case 'multiply':
            if (params.length < 1) error(op + ' must have at least 1 parameter');
            operand = { op: op, operands: [operand].concat(params) };
            break;

          case 'subtract':
            if (params.length < 1) error(op + ' must have at least 1 parameter');
            operand = {
              op: 'add',
              operands: [operand].concat(params.map(function(param) { return { op: 'negate', operand: param }}))
            };
            break;

          case 'divide':
            if (params.length < 1) error(op + ' must have at least 1 parameter');
            operand = {
              op: 'multiply',
              operands: [operand].concat(params.map(function(param) { return { op: 'reciprocate', operand: param }}))
            };
            break;

          case 'not':
          case 'negate':
          case 'reciprocate':
            if (params.length) error(op + ' does not need parameters');
            operand = {
              op: op,
              operand: operand
            };
            break;

          case 'match':
            if (params.length !== 1) error(op + ' must have 1 parameter');
            operand = {
              op: op,
              operand: operand,
              regexp: getName(params[0])
            };
            break;

          case 'numberBucket':
            if (params.length !== 1 && params.length !== 2) error(op + ' must have 1 or 2 parameter');
            operand = {
              op: op,
              operand: operand,
              size: getNumber(params[0])
            };
            if (params.length === 2) operand.offset = getNumber(params[1]);
            break;

          case 'timeBucket':
            if (params.length !== 1 && params.length !== 2) error(op + ' must have 1 or 2 parameter');
            operand = {
              op: op,
              operand: operand,
              duration: getName(params[0])
            };
            if (params.length === 2) operand.timezone = getName(params[1]);
            break;

          case 'substr':
            if (params.length !== 2) error(op + ' must have 2 parameters');
            operand = {
              op: op,
              operand: operand,
              position: getNumber(params[0]),
              length: getNumber(params[1])
            };
            break;

          case 'timePart':
            if (params.length !== 1 && params.length !== 2) error(op + ' must have 1 or 2 parameter');
            operand = {
              op: op,
              operand: operand,
              part: getName(params[0])
            };
            if (params.length === 2) operand.timezone = getName(params[1]);
            break;

          case 'filter':
            if (params.length !== 1) error(op + ' must have 1 parameter');
            addAction({ action: op, expression: params[0] });
            break;

          case 'def':
          case 'apply':
            if (params.length !== 2) error(op + ' must have 2 parameters');
            addAction({ action: op, name: getName(params[0]), expression: params[1] });
            break;

          case 'sort':
            if (params.length !== 2) error(op + ' must have 2 parameters');
            addAction({ action: op, expression: params[0], direction: getName(params[1]) });
            break;

          case 'limit':
            if (params.length !== 1) error(op + ' must have 1 parameter');
            addAction({ action: op, limit: getNumber(params[0]) });
            break;

          case 'count':
            if (params.length) error(op + ' does not need parameters');
            operand = {
              op: 'aggregate',
              fn: op,
              operand: operand
            };
            break;

          case 'sum':
          case 'max':
          case 'min':
          case 'average':
          case 'uniqueCount':
          case 'group':
            if (params.length !== 1) error(op + ' must have 1 parameter');
            operand = {
              op: 'aggregate',
              fn: op,
              operand: operand,
              attribute: params[0]
            };
            break;

          case 'label':
            if (params.length !== 1) error(op + ' must have 1 parameter');
            operand = { op: op, operand: operand, name: getName(params[0]) };
            break;

          case 'split':
            if (params.length !== 2 && params.length !== 3) error(op + ' must have 2 or 3 parameter');
            var attribute = params[0];
            var name = getName(params[1]);
            var dataName = params[2];
            if (!dataName) {
              if (operand.op !== 'ref') error("could not guess data name in `split`, please provide one explicitly");
              dataName = operand.name;
            }
            operand = {
              op: 'actions',
              operand: {
                op: 'label',
                name: name,
                operand: { op: 'aggregate', fn: 'group', attribute: attribute, operand: operand }
              },
              actions: [
                {
                  action: 'def',
                  name: dataName,
                  expression: {
                    op: 'actions',
                    operand: { op: 'ref', name: '^' + dataName },
                    actions: [{
                      action: 'filter',
                      expression: {
                        op: 'is',
                        lhs: attribute,
                        rhs: { op: 'ref', name: '^' + name }
                      }
                    }]
                  }
                }
              ]
            };
            break;

          default:
            error("Unrecognized call of '" + op + "'");
        }
      }
      return operand;
    }

Params
  = head:Param tail:(_ "," _ Param)*
    { return [head].concat(tail.map(function(t) { return t[3] })); }

Param
  = Expression / Name / String

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
  = CallChainExpression
  / "(" _ ex:Expression _ ")" { return ex; }
  / Literal
  / Ref

Leaf
  = "(" _ ex:Expression _ ")" { return ex; }
  / Literal
  / Ref
  / "$()" { return base; }

Ref
  = "$" name:RefName ":" type:TypeName
    { return { op: "ref", name: name, type: type }; }
  / "$" name:RefName
    { return { op: "ref", name: name }; }

Literal
  = number:Number { return { op: "literal", value: number }; }
  / string:String { return { op: "literal", value: string }; }

String "String"
  = "'" chars:NotSQuote "'" { return chars; }
  / "'" chars:NotSQuote { error("Unmatched single quote"); }
  / '"' chars:NotDQuote '"' { return chars; }
  / '"' chars:NotDQuote { error("Unmatched double quote"); }


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
