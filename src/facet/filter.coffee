# { attribute: "make", op: "is", value: "Honda" }
# { attribute: "make", op: "in", values: ["Honda", "BMW"] }
# { attribute: "make", op: "match", expression: "Hond[ao]" }
# { attribute: "displacement", op: "within", range: [5, 6] }
# { op: "not", filter: {...} }
# { op: "and", filters: [{...}] }
# { op: "or", filters: [{...}] }

facet.filter = {
  is: (attribute, value) -> {
    op: 'is'
    attribute
    value
  }

  in: (attribute, values) -> {
    op: 'in'
    attribute
    values
  }

  match: (attribute, expression) -> {
    op: 'match'
    attribute
    expression
  }

  within: (attribute, range) ->
    throw new TypeError("range must be an array of two things") unless Array.isArray(range) and range.length is 2
    return {
      op: 'within'
      attribute
      range
    }

  not: (filter) ->
    throw new TypeError("filter must be a filter object") unless typeof filter is 'object'
    return {
      op: 'not'
      filter
    }

  and: (filters) ->
    throw new TypeError('filters must be a nonempty array') unless Array.isArray(filters) and filters.length
    return {
      op: 'and'
      filters
    }

  or: (filters) ->
    throw new TypeError('filters must be a nonempty array') unless Array.isArray(filters) or filters.length
    return {
      op: 'or'
      filters
    }
}
