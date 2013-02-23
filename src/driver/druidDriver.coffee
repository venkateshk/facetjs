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


druidQuery = {
  all: ({requester, dataSource, interval, filters, condensedQuery}, callback) ->
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

    queryObj = {
      dataSource
      intervals: [toDruidInterval(interval)]
      queryType: "timeseries"
      granularity: "all"
    }

    if filters
      queryObj.filter = filters

    # apply
    if condensedQuery.applies.length > 0
      try
        addApplies(queryObj, condensedQuery.applies)
      catch e
        callback(e)
        return

    requester queryObj, (err, ds) ->
      if err
        callback(err)
        return

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

  timeseries: ({requester, dataSource, interval, filters, condensedQuery}, callback) ->
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

    queryObj = {
      dataSource
      intervals: [toDruidInterval(interval)]
      queryType: "timeseries"
    }

    if filters
      queryObj.filter = filters

    # split + combine
    if not condensedQuery.combine?.sort
      callback("must have a sort combine for a split"); return
    combinePropName = condensedQuery.combine.sort.prop
    if not combinePropName
      callback("must have a sort prop name"); return

    timePropName = condensedQuery.split.prop
    callback("Must sort on the time prop for now (temp)") if combinePropName isnt timePropName
    return

    bucketDuration = condensedQuery.split.duration
    if not bucketDuration
      callback("Must have duration for time bucket"); return
    if not bucketDuration in ['second', 'minute', 'hour', 'day']
      callback("Unsupported duration '#{bucketDuration}' in time bucket"); return
    queryObj.granularity = bucketDuration

    # apply
    if condensedQuery.applies.length > 0
      try
        addApplies(queryObj, condensedQuery.applies)
      catch e
        callback(e)
        return

    requester queryObj, (err, ds) ->
      if err
        callback(err)
        return

      # expand time into an interval
      splits = [{
        prop: { "not": "implemented yet" }
        _interval: interval # wrong
        _filters: filters
      }]

      callback(null, splits)
      return
    return

  topN: ({requester, dataSource, interval, filters, condensedQuery}, callback) ->
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

    queryObj = {
      dataSource
      intervals: [toDruidInterval(interval)]
      queryType: "topN"
      granularity: "all"
    }

    if filters
      queryObj.filter = filters

    # split + combine
    if not condensedQuery.split.attribute
      callback("split must have an attribute"); return
    if not condensedQuery.split.prop
      callback("split must have a prop"); return

    sort = condensedQuery.combine.sort
    if sort.direction not in ['ASC', 'DESC']
      callback("direction has to be 'ASC' or 'DESC'"); return

    # figure out of wee need to invert and apply for a bottom N
    if sort.direction is 'DESC'
      invertApply = null
    else
      invertApply = findApply(condensedQuery.applies, sort.prop)
      if not invertApply
        callback("no apply to invert for bottomN"); return

    queryObj.dimension = {
      type: 'default'
      dimension: condensedQuery.split.attribute
      outputName: condensedQuery.split.prop
    }
    queryObj.threshold = condensedQuery.combine.limit or 10
    queryObj.metric = condensedQuery.combine.sort.prop

    # apply
    if condensedQuery.applies.length > 0
      try
        addApplies(queryObj, condensedQuery.applies, invertApply)
      catch e
        callback(e)
        return

    requester queryObj, (err, ds) ->
      if err
        callback(err)
        return

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

      callback(null, splits)
      return
    return

  histogram: ({requester, dataSource, interval, filters, condensedQuery}, callback) ->
    callback("not implemented yet")
    return
}


exports = ({requester, dataSource, timeAttribute, interval, filters}) ->
  timeAttribute or= 'time'
  return (query, callback) ->
    condensedQuery = driverUtil.condenseQuery(query)

    rootSegment = null
    segments = [rootSegment]

    queryDruid = (condensedQuery, done) ->
      if condensedQuery.split
        switch condensedQuery.split.bucket
          when 'identity'
            if not condensedQuery.combine?.sort
              done("must have a sort combine for a split"); return
            combinePropName = condensedQuery.combine.sort.prop
            if not combinePropName
              done("must have a sort prop name"); return

            if findApply(condensedQuery.applies, combinePropName)
              queryFn = druidQuery.topN
            else
              done('not implemented yet'); return
          when 'time'
            queryFn = druidQuery.timeseries
          when 'continuous'
            queryFn = druidQuery.histogram
          else
            done('unsupported query'); return
      else
        queryFn = druidQuery.all

      queryForSegment = (parentSegment, done) ->
        queryFn({
          requester
          dataSource
          interval: if parentSegment then parentSegment._interval else interval
          filters: if parentSegment then parentSegment._filters else filters
          condensedQuery
        }, (err, splits) ->
          if err
            done(err)
            return
          # Make the results into segments and build the tree
          if parentSegment
            parentSegment.splits = splits
            driverUtil.cleanSegment(parentSegment)
          else
            rootSegment = splits[0]
          done(null, splits)
          return
        )
        return

      # do the query in parallel
      QUERY_LIMIT = 10
      queryFns = async.mapLimit(
        segments
        QUERY_LIMIT
        queryForSegment
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
        segments.forEach(driverUtil.cleanSegment)

        callback(null, rootSegment)
        return
    )
    return


# -----------------------------------------------------
# Handle commonJS crap
if typeof module is 'undefined' then window['druidDriver'] = exports else module.exports = exports
