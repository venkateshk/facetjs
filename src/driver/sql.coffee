async = if typeof window isnt 'undefined' then window.async else require('async')

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
  condensed = []
  for cmd in query
    switch cmd.operation
      when 'split'
        condensed.push(curQuery)
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

  condensed.push(curQuery)
  return condensed

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
    callback(null, {}); return

  selectParts = []
  groupByPart = null

  # split
  split = condensedQuery.split
  if split
    groupByPart = 'GROUP BY '
    switch split.bucket
      when 'natural'
        selectParts.push "`#{split.attribute}` AS \"#{split.prop}\""
        groupByPart += "`#{split.attribute}`"

      when 'time'
        callback("not implemented yet"); return

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
  if filters
    sqlQuery.filter = filters

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
      if sort.direction not in ['ASC', 'DESC']
        callback("direction has to be 'ASC' or 'DESC'"); return

      orderByPart = 'ORDER BY '

      switch sort.compare
        when 'natural'
          orderByPart += "`#{sort.prop}` #{sort.direction}"

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


sql = ({requester, table, filters}) -> (query, callback) ->
  condensedQuery = condenseQuery(query)

  rootSegemnt = null
  segments = [rootSegemnt]

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
            delete parentSegment._filters
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
      querySQL(condenced, done)
      return
    (err) ->
      if err
        callback(err)
        return
      # Clean up the last segments
      for segment in segments
        delete segment._filters
      callback(null, rootSegemnt)
      return
  )



# Add where needed
if facet?.driver?
  facet.driver.sql = sql

if typeof module isnt 'undefined' and typeof exports isnt 'undefined'
  module.exports = sql
