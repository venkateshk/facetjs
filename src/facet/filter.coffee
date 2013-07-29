# { attribute: "make", type: "is", value: "Honda" }
# { attribute: "make", type: "in", values: ["Honda", "BMW"] }
# { attribute: "make", type: "match", expression: "Hond[ao]" }
# { attribute: "displacement", type: "within", range: [5, 6] }
# { type: "not", filter: {...} }
# { type: "and", filters: [{...}] }
# { type: "or", filters: [{...}] }

facet.filter = {
  true: -> {
    type: 'true'
  }

  false: -> {
    type: 'false'
  }

  is: (attribute, value) -> {
    type: 'is'
    attribute
    value
  }

  in: (attribute, values) -> {
    type: 'in'
    attribute
    values
  }

  fragments: (attribute, fragments) -> {
    type: 'fragments'
    attribute
    fragments
  }

  match: (attribute, expression) -> {
    type: 'match'
    attribute
    expression
  }

  within: (attribute, range) ->
    throw new TypeError("range must be an array of two things") unless Array.isArray(range) and range.length is 2
    return {
      type: 'within'
      attribute
      range
    }

  not: (filter) ->
    throw new TypeError("filter must be a filter object") unless typeof filter is 'object'
    return {
      type: 'not'
      filter
    }

  and: (filters...) ->
    throw new TypeError('must have some filters') unless filters.length
    return {
      type: 'and'
      filters
    }

  or: (filters...) ->
    throw new TypeError('must have some filters') unless filters.length
    return {
      type: 'or'
      filters
    }
}
