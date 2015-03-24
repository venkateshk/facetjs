start
  = _ ex:Expression _ { return ex; }

Expression
  = BinaryExpression
  / AdditiveExpression
  / CallChainExpression

CallChainExpression
  = lhs:Leaf tail:(_ "." _ CallFn "(" _ Params _ ")")+
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
        throw new Error("invalid parameter");
      }

      for (var i = 0, n = tail.length; i < n; i++) {
        var part = tail[i];
        var op = part[3];
        var params = part[6];
        switch (op) {
          case 'is':
          case 'in':
          case 'lessThanOrEqual':
          case 'greaterThanOrEqual':
          case 'lessThan':
          case 'greaterThan':
            if (params.length !== 1) throw new Error(op + ' must have 1 parameter');
            operand = { op: op, lhs: operand, rhs: params[0] };
            break;

          case 'add':
          case 'multiply':
            if (params.length < 1) throw new Error(op + ' must have at least 1 parameter');
            operand = { op: op, operands: [operand].concat(params) };
            break;

          case 'subtract':
            if (params.length < 1) throw new Error(op + ' must have at least 1 parameter');
            operand = {
              op: 'add',
              operands: [operand].concat(params.map(function(param) { return { op: 'negate', operand: param }}))
            };
            break;

          case 'divide':
            if (params.length < 1) throw new Error(op + ' must have at least 1 parameter');
            operand = {
              op: 'multiply',
              operands: [operand].concat(params.map(function(param) { return { op: 'reciprocate', operand: param }}))
            };
            break;

          case 'filter':
            if (params.length !== 1) throw new Error(op + ' must have 1 parameter');
            addAction({ action: op, expression: params[0] });
            break;

          case 'def':
          case 'apply':
            if (params.length !== 2) throw new Error(op + ' must have 2 parameters');
            addAction({ action: op, name: getName(params[0]), expression: params[1] });
            break;

          case 'sort':
            if (params.length !== 2) throw new Error(op + ' must have 2 parameters');
            addAction({ action: op, expression: params[0], direction: getName(params[1]) });
            break;

          case 'limit':
            if (params.length !== 1) throw new Error(op + ' must have 1 parameter');
            if (params[0].op !== 'literal')
            addAction({ action: op, limit: params[0].value });
            break;

          case 'count':
            if (params.length) throw new Error(op + ' can not have parameters');
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
            if (params.length !== 1) throw new Error(op + ' must have 1 parameter');
            operand = {
              op: 'aggregate',
              fn: op,
              operand: operand,
              attribute: params[0]
            };
            break;

          case 'label':
            if (params.length !== 1) throw new Error(op + ' must have 1 parameter');
            operand = { op: op, operand: operand, name: getName(params[0]) };
            break;

          default:
            throw new Error("Unrecognized call of '" + op + "'");
        }
      }
      return operand;
    }

Params
  = head:Param? tail:(_ "," _ Param)*
    {
      if (!head) return [];
      return [head].concat(tail.map(function(t) { return t[3] }));
    }

Param
  = Expression / Name

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
  / "facet()" { return { op: 'literal', value: [{}] }; }

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
  = $([^']+)

NotDQuote "NotDQuote"
  = $([^"]+)

_ "Whitespace"
  = $([ \t\r\n]*)
