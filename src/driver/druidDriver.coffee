rq = (module) ->
  if typeof window is 'undefined'
    return require(module)
  else
    moduleParts = module.split('/')
    return window[moduleParts[moduleParts.length - 1]]

async = rq('async')
driverUtil = rq('./driverUtil')

if typeof exports is 'undefined'
  exports = {}

# -----------------------------------------------------

makeFilter = (attribute, value) ->
  return {
    type: 'selector'
    dimension: attribute
    value: value
  }

andFilters = (filters...) ->
  filters = filters.filter((filter) -> filter?)
  switch filters.length
    when 0
      return null
    when 1
      return filters[0]
    else
      return {
        type: 'and'
        fields: filters
      }


findApply = (applies, propName) ->
  for apply in applies
    return apply if apply.prop is propName
  return

findCountApply = (applies) ->
  for apply in applies
    return apply if apply.aggregate is 'count'
  return

toDruidInterval = (interval) ->
  return interval.map((d) -> d.toISOString().replace('Z', '')).join('/')


addApplies = (druidQuery, applies, invertApply) ->
  countPropName = null
  druidQuery.aggregations = []
  for apply in applies
    switch apply.aggregate
      when 'count'
        if apply isnt invertApply
          countPropName = apply.prop
          druidQuery.aggregations.push {
            type: "count"
            name: apply.prop
          }
        else
          throw new Error("not implemented yet")

      when 'sum'
        if apply isnt invertApply
          druidQuery.aggregations.push {
            type: "doubleSum"
            name: apply.prop
            fieldName: apply.attribute
          }
        else
          throw new Error("not implemented yet")

      when 'average'
        if apply isnt invertApply
          callback("not implemented correctly yet")
          return
          druidQuery.aggregations.push {
            type: "doubleSum"
            name: apply.prop
            fieldName: apply.attribute
          }
          # Add postagg to do divide
        else
          throw new Error("not implemented yet")

      when 'min'
        if apply isnt invertApply
          druidQuery.aggregations.push {
            type: "min"
            name: apply.prop
            fieldName: apply.attribute
          }
        else
          throw new Error("not implemented yet")

      when 'max'
        if apply isnt invertApply
          druidQuery.aggregations.push {
            type: "max"
            name: apply.prop
            fieldName: apply.attribute
          }
        else
          throw new Error("not implemented yet")

      when 'unique'
        if apply is invertApply
          throw new Error("not implemented yet")
        else
          throw new Error("not implemented yet")
  return


condensedQueryToDruid = ({requester, dataSource, interval, filters, condensedQuery}, callback) ->

  if interval?.length isnt 2
    callback("Must have valid interval [start, end]"); return

  if condensedQuery.applies.length is 0
    # Nothing to do as we are not calculating anything (not true, fix this)
    callback(null, [{
      prop: {}
      _interval: interval
      _filters: filters
    }])
    return

  druidQuery = {
    dataSource
    intervals: [toDruidInterval(interval)]
  }

  if filters
    druidQuery.filter = filters

  # split + combine
  invertApply = null
  if condensedQuery.split
    if not condensedQuery.combine?.sort
      callback("must have a sort combine for a split"); return
    combinePropName = condensedQuery.combine.sort.prop
    if not combinePropName
      callback("must have a sort prop name"); return

    switch condensedQuery.split.bucket
      when 'identity'
        if findApply(condensedQuery.applies, combinePropName)
          if not condensedQuery.split.attribute
            callback("split must have an attribute"); return
          if not condensedQuery.split.prop
            callback("split must have a prop"); return

          sort = condensedQuery.combine.sort
          if sort.direction not in ['ASC', 'DESC']
            callback("direction has to be 'ASC' or 'DESC'"); return

          # figure out of wee need to invert and apply for a bottom N
          if sort.direction is 'ASC'
            invertApply = findApply(condensedQuery.applies, sort.prop)
            if not invertApply
              callback("no apply to invert for bottomN"); return

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
    try
      addApplies(druidQuery, condensedQuery.applies, invertApply)
    catch e
      callback(e)
      return

  requester druidQuery, (err, ds) ->
    if err
      callback(err)
      return

    if condensedQuery.split
      switch condensedQuery.split.bucket
        when 'identity'
          if ds.length isnt 1
            callback("something went wrong")
            return
          filterAttribute = condensedQuery.split.attribute
          filterValueProp = condensedQuery.split.prop
          splits = ds[0].result.map (prop) -> {
            prop
            _interval: interval
            _filters: andFilters(filters, makeFilter(filterAttribute, prop[filterValueProp]))
          }

        when 'time'
          # expand time into an interval
          splits = [{
            prop: { "not": "implemented yet" }
            _interval: interval # wrong
            _filters: filters
          }]

        else
          callback("Unsupported bucketing '#{condensedQuery.split.bucket}' in split post process")
          return
    else
      if ds.length isnt 1
        callback("something went wrong")
        return
      splits = [{
        prop: ds[0].result
        _interval: interval
        _filters: filters
      }]

    callback(null, splits)
    return
  return


exports = ({requester, dataSource, timeAttribute, interval, filters}) ->
  timeAttribute or= 'time'
  return (query, callback) ->
    condensedQuery = driverUtil.condenseQuery(query)

    rootSegment = null
    segments = [rootSegment]
    # todo: change to rootSegments

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
            interval: if parentSegment then parentSegment._interval else interval
            filters: if parentSegment then parentSegment._filters else filters
            condensedQuery: condensed
          }, (err, splits) ->
            if err
              done(err)
              return
            # Make the results into segments and build the tree
            if parentSegment
              parentSegment.splits = splits
              delete parentSegment._interval
              delete parentSegment._filters
            else
              rootSegment = splits[0]
            done(null, splits)
            return
          )
        (err, results) ->
          if err
            done(err)
            return
          segments = driverUtil.flatten(results)
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
        # Clean up the last segments
        for segment in segments
          delete segment._interval
          delete segment._filters

        callback(null, rootSegment)
        return
    )
    return


# -----------------------------------------------------
# Handle commonJS crap
if typeof module is 'undefined' then window['druidDriver'] = exports else module.exports = exports
