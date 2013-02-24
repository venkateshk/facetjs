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
  return "`#{attribute}`=\"#{value}\"" # ToDo: escape

andFilters = (filters...) ->
  filters = filters.filter((filter) -> filter?)
  switch filters.length
    when 0
      return null
    when 1
      return filters[0]
    else
      filters.join(' AND ')

timeBucketing = {
  second: {
    select: '%Y-%m-%dT%H:%i:%SZ'
    group: '%Y-%m-%dT%H:%i:%SZ'
  }
  minute: {
    select: '%Y-%m-%dT%H:%i:00Z'
    group: '%Y-%m-%dT%H:%i'
  }
  hour: {
    select: '%Y-%m-%dT%H:00:00Z'
    group: '%Y-%m-%dT%H'
  }
  day: {
    select: '%Y-%m-%dT00:00:00Z'
    group: '%Y-%m-%d'
  }
  month: {
    select: '%Y-%m-00T00:00:00Z'
    group: '%Y-%m'
  }
  year: {
    select: '%Y-00-00T00:00:00Z'
    group: '%Y'
  }
}

directionMap = {
  ascending:  'ASC'
  descending: 'DESC'
}

condensedQueryToSQL = ({requester, table, filters, condensedQuery}, callback) ->
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
    callback(null, [{
      prop: {}
    }])
    return

  selectParts = []
  groupByPart = null

  # split
  split = condensedQuery.split
  if split
    selectPart = ''
    groupByPart = 'GROUP BY '
    switch split.bucket
      when 'identity'
        selectPart  += "`#{split.attribute}`"
        groupByPart += "`#{split.attribute}`"

      when 'continuous'
        selectPart  += "FLOOR((`#{split.attribute}` + #{split.offset}) / #{split.size}) * #{split.size}"
        groupByPart += "FLOOR((`#{split.attribute}` + #{split.offset}) / #{split.size}) * #{split.size}"

      when 'time'
        bucketDuration = split.duration
        bucketSpec = timeBucketing[bucketDuration]
        if not bucketSpec
          callback("unsupported time bucketing duration '#{bucketDuration}'"); return
        selectPart  += "DATE_FORMAT(`#{split.attribute}`, '#{bucketSpec.select}')"
        groupByPart += "DATE_FORMAT(`#{split.attribute}`, '#{bucketSpec.group}')"

      else
        callback("unsupported bucketing policy '#{split.bucket}'"); return

    selectPart += " AS \"#{split.prop}\""
    selectParts.push(selectPart)

  # apply
  for apply in condensedQuery.applies
    switch apply.aggregate
      when 'count'
        selectParts.push "COUNT(*) AS \"#{apply.prop}\""

      when 'sum'
        selectParts.push "SUM(`#{apply.attribute}`) AS \"#{apply.prop}\""

      when 'average'
        selectParts.push "AVG(`#{apply.attribute}`) AS \"#{apply.prop}\""

      when 'min'
        selectParts.push "MIN(`#{apply.attribute}`) AS \"#{apply.prop}\""

      when 'max'
        selectParts.push "MAX(`#{apply.attribute}`) AS \"#{apply.prop}\""

      when 'unique'
        selectParts.push "COUNT(DISTINCT `#{apply.attribute}`) AS \"#{apply.prop}\""

  # filter
  filterPart = null
  if filters
    filterPart = 'WHERE ' + filters

  # combine
  orderByPart = null
  limitPart = null
  combine = condensedQuery.combine
  if combine
    sort = combine.sort
    if sort
      if not sort.prop
        callback("must have a sort prop name"); return
      if not sort.direction
        callback("must have a sort direction"); return
      sqlDirection = directionMap[sort.direction]
      if not sqlDirection
        callback("direction has to be 'ascending' or 'descending'"); return

      orderByPart = 'ORDER BY '

      switch sort.compare
        when 'natural'
          orderByPart += "`#{sort.prop}` #{sqlDirection}"

        when 'caseInsensetive'
          callback("not implemented yet"); return

        else
          callback("unsupported compare"); return

    if combine.limit?
      if isNaN(combine.limit)
        callback("limit must be a number"); return
      limitPart = "LIMIT #{combine.limit}"

  sqlQuery = [
    'SELECT'
    selectParts.join(', ')
    "FROM `#{table}`"
    filterPart
    groupByPart
    orderByPart
    limitPart
  ].filter((part) -> part?).join(' ') + ';'

  requester sqlQuery, (err, ds) ->
    if err
      callback(err)
      return

    if condensedQuery.split
      filterAttribute = condensedQuery.split.attribute
      filterValueProp = condensedQuery.split.prop
      splits = ds.map (prop) -> {
        prop
        _filters: andFilters(filters, makeFilter(filterAttribute, prop[filterValueProp]))
      }
    else
      splits = ds.map (prop) -> {
        prop
        _filters: filters
      }

    callback(null, splits)
    return
  return


exports = ({requester, table, filters}) -> (query, callback) ->
  condensedQuery = driverUtil.condenseQuery(query)

  rootSegment = null
  segments = [rootSegment]

  querySQL = (condensed, done) ->
    # do the query in parallel
    QUERY_LIMIT = 10
    queryFns = async.mapLimit(
      segments
      QUERY_LIMIT
      (parentSegment, done) ->
        condensedQueryToSQL({
          requester
          table
          filters: if parentSegment then parentSegment._filters else filters
          condensedQuery: condensed
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
      querySQL(condenced, done)
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


# -----------------------------------------------------
# Handle commonJS crap
if typeof module is 'undefined' then window['sqlDriver'] = exports else module.exports = exports
