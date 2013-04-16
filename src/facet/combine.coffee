# COMBINE

facet.combine = {
  slice: (sort, limit) -> {
    combine: 'slice'
    sort
    limit
  }
}


# SORT

facet.sort = {
  natural: (prop, direction = 'descending') -> {
    compare: 'natural'
    prop
    direction
  }

  caseInsensetive: (prop, direction = 'descending') -> {
    compare: 'caseInsensetive'
    prop
    direction
  }
}