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

rangeToDruidInterval = (interval) ->
  return interval.map((d) -> d.toISOString().replace('Z', '')).join('/')

filterToDruidQueryHelper = (filter) ->

  return

filterToDruidQuery = (filter, timeDimension, druidQuery) ->
  if filter.op is 'range' and filter.attribute is timeDimension
    druidQuery.intervals
  return


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
    return apply if apply.name is propName
  return

findCountApply = (applies) ->
  for apply in applies
    return apply if apply.aggregate is 'count'
  return

addApplies = (druidQuery, applies) ->
  applies = applies.slice()
  druidQuery.aggregations = []
  druidQuery.postAggregations = []
  applyIdx = 0
  while applyIdx < applies.length # Note that the apply list can grow
    apply = applies[applyIdx++]
    throw new Error("apply must have prop") unless apply.name
    switch apply.aggregate
      when 'constant'
        druidQuery.postAggregations.push {
          type: "constant"
          name: apply.name
          value: apply.value
        }

      when 'count'
        druidQuery.aggregations.push {
          type: "count"
          name: apply.name
        }

      when 'sum'
        druidQuery.aggregations.push {
          type: "doubleSum"
          name: apply.name
          fieldName: apply.attribute
        }

      when 'average'
        # Ether use an existing count or make a temp one
        countApply = findCountApply(applies)
        if not countApply
          applies.push(countApply = {
            operation: 'apply'
            aggregate: 'count'
            prop: '_count'
          })

        # Ether use an existing sum or make a temp one
        sumApply = null
        for a in applies
          if a.aggregate is 'sum' and a.attribute is apply.attribute
            sumApply = a
            break
        if not sumApply
          applies.push(sumApply = {
            operation: 'apply'
            aggregate: 'sum'
            prop: '_sum_' + apply.attribute
            attribute: apply.attribute
          })

        druidQuery.postAggregations.push {
          type: "arithmetic"
          name: apply.name
          fn: "/"
          fields: [
            { type: "fieldAccess", fieldName: sumApply.name }
            { type: "fieldAccess", fieldName: countApply.name }
          ]
        }

      when 'min'
        druidQuery.aggregations.push {
          type: "min"
          name: apply.name
          fieldName: apply.attribute
        }

      when 'max'
        druidQuery.aggregations.push {
          type: "max"
          name: apply.name
          fieldName: apply.attribute
        }

      when 'uniqueCount'
        # ToDo: add a throw here in case the user us using open source druid
        druidQuery.aggregations.push {
          type: "hyperUnique"
          name: apply.name
          fieldName: apply.attribute
        }

      when 'quantile'
        throw new Error("quantile apply must have quantile") unless apply.quantile
        druidQuery.aggregations.push {
          type: "approxHistogramFold"
          name: '_' + apply.attribute
          fieldName: apply.attribute # ToDo: make it so that approxHistogramFolds can be shared
        }
        druidQuery.postAggregations.push {
          type: "quantile"
          name: apply.name
          fieldName: '_' + apply.attribute
          probability: apply.quantile
        }

      else
        throw new Error("No supported aggregation #{apply.aggregate}")

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

    timePropName = condensedQuery.split.name
    if combinePropName isnt timePropName
      callback("Must sort on the time prop for now (temp)"); return

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

      # ToDo: implement actual timezones
      durationMap = {
        second: 1000
        minute: 60 * 1000
        hour: 60 * 60 * 1000
        day: 24 * 60 * 60 * 1000
      }

      if condensedQuery.combine.sort.direction is 'descending'
        ds.reverse()

      if condensedQuery.combine.limit?
        limit = condensedQuery.combine.limit
        ds.splice(limit, ds.length - limit)

      splits = ds.map (d) ->
        timestampStart = new Date(d.timestamp)
        timestampEnd = new Date(timestampStart.valueOf() + durationMap[bucketDuration])
        split = {
          prop: d.result
          _interval: [timestampStart, timestampEnd]
          _filters: filters
        }

        split.prop[timePropName] = [timestampStart, timestampEnd]
        return split

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
    if not condensedQuery.split.name
      callback("split must have a prop"); return

    sort = condensedQuery.combine.sort
    if sort.direction not in ['ascending', 'descending']
      callback("direction has to be 'ascending' or 'descending'"); return

    # figure out of wee need to invert and apply for a bottomN
    if sort.direction is 'descending'
      invertApply = null
    else
      invertApply = findApply(condensedQuery.applies, sort.prop)
      if not invertApply
        callback("no apply to invert for bottomN"); return

    queryObj.dimension = {
      type: 'default'
      dimension: condensedQuery.split.attribute
      outputName: condensedQuery.split.name
    }
    queryObj.threshold = condensedQuery.combine.limit or 10
    queryObj.metric = (if invertApply then '_inv_' else '') + condensedQuery.combine.sort.prop

    # apply
    if condensedQuery.applies.length > 0
      try
        addApplies(queryObj, condensedQuery.applies, invertApply)
      catch e
        callback(e)
        return

    if invertApply
      queryObj.postAggregations.push {
        type: "arithmetic"
        name: '_inv_' + invertApply.prop
        fn: "*"
        fields: [
          { type: "fieldAccess", fieldName: invertApply.prop }
          { type: "constant", value: -1 }
        ]
      }

    if queryObj.postAggregations.length is 0
      delete queryObj.postAggregations

    requester queryObj, (err, ds) ->
      if err
        callback(err)
        return

      if ds.length isnt 1
        callback("something went wrong")
        return

      filterAttribute = condensedQuery.split.attribute
      filterValueProp = condensedQuery.split.name
      splits = ds[0].result.map (prop) -> {
        prop
        _interval: interval
        _filters: andFilters(filters, makeFilter(filterAttribute, prop[filterValueProp]))
      }

      callback(null, splits)
      return
    return

  histogram: ({requester, dataSource, interval, filters, condensedQuery}, callback) ->
    callback("not implemented yet"); return
    # data.queryType = "timeseries"
    # data.postAggregations = null
    # data.aggregations = [
    #   {
    #     type: "approxHistogramFold"
    #     name: obj.dimension #"delta_hist"
    #     fieldName: obj.dimension + '_hist' # "delta_hist" ToDo: do not hard code 'hist'
    #     outputSize: obj.bucket
    #     probabilities: [0.25, 0.5, 0.75]
    #   }
    # ]
    return
}


exports = ({requester, dataSource, timeAttribute, aproximate, interval, filters}) ->
  timeAttribute or= 'time'
  aproximate ?= true
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

            if findApply(condensedQuery.applies, combinePropName) and aproximate
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
