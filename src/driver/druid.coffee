applyToAggregation = (segment, {prop, aggregate, attribute}) ->
  _query = segment._query
  _query.aggregations or= []
  switch aggregate
    when 'count'
      segment._sumProp = prop
      _query.aggregations.push {
        type: "doubleSum"
        name: prop
        fieldName: 'count'
      }

    when 'sum'
      _query.aggregations.push {
        type: "doubleSum" # aggregate
        name: prop
        fieldName: attribute
      }

    when 'average'
      _query.aggregations.push {
        type: "doubleSum" # aggregate
        name: prop
        fieldName: attribute
      }

    when 'unique'
      throw 'todo'

    else


druid = ({dataSource, start, end, filters, requester}) -> (query, callback) ->
  start = start.toISOString().replace('Z', '')
  end = end.toISOString().replace('Z', '')
  intervals = ["#{start}/#{end}"]


  rootSegment = {
    _query: {
      dataSource
      intervals
      queryType: "timeseries"
      granularity: "all"
    }
    prop: {}
  }
  segments = [rootSegment]

  queryIfNeeded = ->
    segments.forEach (segment) ->
      if not segment._query.aggregations
        return

      # do the query
      return

  for cmd in query
    switch cmd.operation
      when 'split'
        queryIfNeeded()

      when 'apply'
        { prop, aggregate, attribute } = cmd
        for segment in segments
          applyToAggregation(segment, cmd)

      when 'combine'
        null

      else
        throw new Error("Unknown operation '#{cmd.operation}'")

  queryIfNeeded()

  requester initQuery, (err, res) ->
    console.log err, res


# Add where needed
if facet?.driver?
  facet.driver.druid = druid

if typeof module isnt 'undefined' and typeof exports isnt 'undefined'
  module.exports = druid
