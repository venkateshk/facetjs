module.exports = {
  natural: (prop, direction = 'descending') -> {
    compare: 'natural'
    prop
    direction
  }

  caseInsensitive: (prop, direction = 'descending') -> {
    compare: 'caseInsensitive'
    prop
    direction
  }
}
