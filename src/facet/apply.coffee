# An apply is a function that takes an array of rows and returns a number.

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

