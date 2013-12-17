module.exports = {
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
