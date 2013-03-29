# An apply is a function that takes an array of rows and returns a number.

###
How facet applies work:

constant:
  Facet:
    {
      name: 'SomeConstant'
      aggregate: 'constant'
      value: 1337
    }

  SQL:
    1337 AS "SomeConstant"

count:
  Facet:
    {
      name: 'Count'
      aggregate: 'count'
    }
  SQL:
    COUNT(1) AS "Count"

sum, average, min, max, uniqueCount:
  Facet:
    {
      name: 'Revenue'
      aggregate: 'sum' # / average / min / max / uniqueCount
      attribute: 'revenue' # This is a druid 'metric'
    }
  SQL:
    SUM(`revenue`) AS "Revenue"
    AVG ...
    MIN ...
    MAX ...
    COUNT(DISTICT ...

add, subtract, multiply, divide:
  Facet:
    {
      name: 'Sum Of Things'
      arithmetic: 'add' # / subtract / multiply / divide
      operands: [<apply1>, <apply2>]
    }
  SQL:

###

facet.apply = {
  constant: (value) ->
    return {
      aggregate: 'constant'
      value
    }

  count: ->
    return {
      aggregate: 'count'
    }

  quantile: (attribute, quantile) ->
    throw new TypeError('bad quantile') unless 0 <= quantile <= 1
    return {
      aggregate: 'quantile'
      attribute
      quantile
    }
}

# Single attribute
['sum', 'average', 'min', 'max', 'uniqueCount'].forEach (agg) ->
  facet.apply[agg] = (attribute) ->
    throw new TypeError('must have a string attribute') unless typeof attribute is 'string'
    return {
      aggregate: agg
      attribute
    }

# Two operands
['add', 'subtract', 'multiply', 'divide'].forEach (op) ->
  facet.apply[op] = (lhs, rhs) ->
    throw new TypeError('lhs must be an object') unless typeof lhs is 'object'
    throw new TypeError('rhs must be an object') unless typeof rhs is 'object'
    return {
      arithmetic: op
      operands: [lhs, rhs]
    }


