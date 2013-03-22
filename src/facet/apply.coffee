# An apply is a function that takes an array of rows and returns a number.

facet.apply = {
  constant: (value) -> {
    aggregate: 'constant'
    value
  }

  count: -> {
    aggregate: 'count'
  }

  sum: (attribute) -> {
    aggregate: 'sum'
    attribute
  }

  average: (attribute) -> {
    aggregate: 'average'
    attribute
  }

  min: (attribute) -> {
    aggregate: 'min'
    attribute
  }

  max: (attribute) -> {
    aggregate: 'max'
    attribute
  }

  unique: (attribute) -> {
    aggregate: 'unique'
    attribute
  }

  quantile: (attribute, quantile) ->
    throw new TypeError('bad quantile') unless 0 <= quantile <= 1
    return {
      aggregate: 'quantile'
      attribute
      quantile
    }
}