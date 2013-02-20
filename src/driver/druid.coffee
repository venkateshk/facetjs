# Utils

flatten = (ar) -> Array::concat.apply([], ar)

# ===================================

# group the queries steps in to the logical queries that will need to be done
# output: [
#   {
#     split: { ... }
#     applies: [{ ... }, { ... }]
#     combine: { ... }
#   }
#   ...
# ]
condenseQuery = (query) ->
  curQuery = {
    split: null
    applies: []
    combine: null
  }
  condenseted = []
  for cmd in query
    switch cmd.operation
      when 'split'
        condenseted.push(curQuery)
        curQuery = {
          split: cmd
          applies: []
          combine: null
        }

      when 'apply'
        curQuery.applies.push(cmd)

      when 'combine'
        throw new Error("Can not have more than one combine") if curQuery.combine
        curQuery.combine = cmd

      else
        throw new Error("Unknown operation '#{cmd.operation}'")

  condenseted.push(curQuery)
  return condenseted


condensedQueryToDruid = ({requester, dataSource, intervals, filters, condensedQuery}, callback) ->
  findApply = (applies, propName) ->
    for apply in applies
      return apply if apply.prop is propName
    return

  findCountApply = (applies) ->
    for apply in applies
      return apply if apply.aggregate is 'count'
    return

  if condensedQuery.applies.length is 0
    # Nothing to do as we are not calculating anything (not true, fix this)
    callback(null, {})
    return

  druidQuery = {
    dataSource
    intervals
  }

  if filters
    druidQuery.filters = filters

  # split + combine
  if condensedQuery.split
    if not condensedQuery.combine?.sort
      callback("must have a sort combine for a split"); return
    combinePropName = condensedQuery.combine.sort.prop
    if not combinePropName
      callback("must have a sort prop name"); return

    switch condensedQuery.split.bucket
      when 'natural'
        if findApply(condensedQuery.applies, combinePropName)
          if not condensedQuery.split.attribute
            callback("split must have an attribute"); return
          if not condensedQuery.split.prop
            callback("split must have a prop"); return

          druidQuery.queryType = "topN"
          druidQuery.granularity = "all"
          druidQuery.dimension = {
            type: 'default'
            dimension: condensedQuery.split.attribute
            outputName: condensedQuery.split.prop
          }
          druidQuery.threshold = condensedQuery.combine.limit or 10
          druidQuery.metric = combinePropName
        else
          callback("not supported yet"); return

      when 'time'
        druidQuery.queryType = "timeseries"

        timePropName = condensedQuery.split.prop
        callback("Must sort on the time prop for now (temp)") if combinePropName isnt timePropName
        return

        bucketDuration = condensedQuery.split.duration
        if not bucketDuration
          callback("Must have duration for time bucket"); return
        if not bucketDuration in ['second', 'minute', 'hour', 'day']
          callback("Unsupported duration '#{bucketDuration}' in time bucket"); return
        druidQuery.granularity = bucketDuration

      else
        callback("Unsupported bucketing '#{condensedQuery.split.bucket}' in split"); return

  else
    druidQuery.queryType = "timeseries"
    druidQuery.granularity = "all"

  # apply
  if condensedQuery.applies.length > 0
    countPropName = null
    druidQuery.aggregations = []
    for apply in condensedQuery.applies
      switch apply.aggregate
        when 'count'
          countPropName = apply.prop
          druidQuery.aggregations.push {
            type: "doubleSum"
            name: apply.prop
            fieldName: 'count'
          }

        when 'sum'
          druidQuery.aggregations.push {
            type: "doubleSum"
            name: apply.prop
            fieldName: apply.attribute
          }

        when 'average'
          druidQuery.aggregations.push {
            type: "doubleSum"
            name: apply.prop
            fieldName: apply.attribute
          }
          # Add postagg to do divide

        when 'unique'
          callback("not implemented yet")
          return

  requester druidQuery, (err, ds) ->
    if err
      callback(err)
      return

    if condensedQuery.split
      switch condensedQuery.split.bucket
        when 'natural'
          if ds.length isnt 1
            callback("something went wrong")
            return
          result = ds[0].result

        when 'time'
          result = { "not": "implemented yet" }

        else
          callback("Unsupported bucketing '#{condensedQuery.split.bucket}' in split post process")
          return
    else
      if ds.length isnt 1
        callback("something went wrong")
        return
      result = ds.map((d) -> d.result)

    callback(null, result)
    return
  return


druid = ({requester, dataSource, start, end, filters}) -> (query, callback) ->
  condensedQuery = condenseQuery(query)
  start = start.toISOString().replace('Z', '')
  end = end.toISOString().replace('Z', '')
  intervals = ["#{start}/#{end}"]

  rootSegemnt = null
  segments = [rootSegemnt]

  queryDruid = (condensed, done) ->
    # do the query in parallel
    QUERY_LIMIT = 10
    queryFns = async.mapLimit(
      segments
      QUERY_LIMIT
      (parentSegment, done) ->
        condensedQueryToDruid({
          requester
          dataSource
          intervals
          filters: null # todo
          condensedQuery: condensed
        }, (err, props) ->
          if err
            done(err)
            return
          # Make the results into segments and build the tree
          splits = props.map((prop) -> { prop })
          if parentSegment
            parentSegment.splits = splits
          else
            rootSegemnt = splits[0]
          done(null, splits)
          return
        )
      (err, results) ->
        if err
          done(err)
          return
        segments = flatten(results)
        done()
        return
    )
    return

  cmdIndex = 0
  async.whilst(
    -> cmdIndex < condensedQuery.length
    (done) ->
      condenced = condensedQuery[cmdIndex]
      cmdIndex++
      queryDruid(condenced, done)
      return
    (err) ->
      if err
        callback(err)
        return
      callback(null, rootSegemnt)
      return
  )



# Add where needed
if facet?.driver?
  facet.driver.druid = druid

if typeof module isnt 'undefined' and typeof exports isnt 'undefined'
  module.exports = druid
