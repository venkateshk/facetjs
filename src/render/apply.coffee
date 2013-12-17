apply = {
  constant: (value, options) ->
    applySpec = {
      aggregate: 'constant'
      value
    }
    applySpec.options = options if options
    return applySpec

  count: (options) ->
    applySpec = {
      aggregate: 'count'
    }
    applySpec.options = options if options
    return applySpec

  quantile: (attribute, quantile, options) ->
    throw new TypeError('bad quantile') unless 0 <= quantile <= 1
    applySpec = {
      aggregate: 'quantile'
      attribute
      quantile
    }
    applySpec.options = options if options
    return applySpec
}

# Single attribute
['sum', 'average', 'min', 'max', 'uniqueCount'].forEach (agg) ->
  apply[agg] = (attribute, options) ->
    throw new TypeError('must have a string attribute') unless typeof attribute is 'string'
    applySpec = {
      aggregate: agg
      attribute
    }
    applySpec.options = options if options
    return applySpec

# Arithmetic
['add', 'subtract', 'multiply', 'divide'].forEach (op) ->
  apply[op] = (lhs, rhs) ->
    throw new TypeError('lhs must be an object') unless typeof lhs is 'object'
    throw new TypeError('rhs must be an object') unless typeof rhs is 'object'
    return {
      arithmetic: op
      operands: [lhs, rhs]
    }

module.exports = apply
