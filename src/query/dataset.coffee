{specialJoin, getValueOf, find, dummyObject} = require('./common')
{FacetFilter, TrueFilter} = require('./filter')

class FacetDataset
  operation: 'dataset'

  constructor: ({@name, @source, filter}) ->
    throw new TypeError("dataset name must be a string") unless typeof @name is 'string'
    throw new TypeError("dataset source must be a string") unless typeof @source is 'string'
    @filter = FacetFilter.fromJS(filter) if filter
    return

  toString: ->
    return "Dataset:#{@name}"

  getFilter: ->
    return @filter or new TrueFilter()

  valueOf: ->
    spec = {
      @name
      @source
    }
    spec.filter = @filter.valueOf() if @filter
    return spec

  toJSON: -> @valueOf.apply(this, arguments)

  isEqual: (other) ->
    return Boolean(other) and
           @source is other.source and
           @getFilter().isEqual(other.getFilter())


FacetDataset.base = new FacetDataset({
  name: 'main'
  source: 'base'
})


# Export!
exports.FacetDataset = FacetDataset

