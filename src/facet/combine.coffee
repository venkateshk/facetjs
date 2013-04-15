# COMBINE

facet.combine = {
  sortSlice: (sort, limit) -> {
    combine: 'sortSlice'
    sort
    limit
  }
}


# SORT

facet.sort = {
  natural: (attribute, direction = 'descending') -> {
    compare: 'natural'
    attribute
    direction
  }

  caseInsensetive: (attribute, direction = 'descending') -> {
    compare: 'caseInsensetive'
    attribute
    direction
  }
}