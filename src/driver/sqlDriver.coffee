"use strict"

async = require('async')
{Duration} = require('chronology')

{isInstanceOf} = require('../util')
driverUtil = require('./driverUtil')
SegmentTree = require('./segmentTree')
{
  FacetFilter, TrueFilter, AndFilter
  FacetSplit
  FacetApply
  FacetCombine
  FacetQuery
  ApplySimplifier
} = require('../query')

# -----------------------------------------------------

aggregateToSqlFn = {
  count:       (c) -> "COUNT(#{c})"
  sum:         (c) -> "SUM(#{c})"
  average:     (c) -> "AVG(#{c})"
  min:         (c) -> "MIN(#{c})"
  max:         (c) -> "MAX(#{c})"
  uniqueCount: (c) -> "COUNT(DISTINCT #{c})"
}

aggregateToZero = {
  count:       "NULL"
  sum:         "0"
  average:     "NULL"
  min:         "NULL"
  max:         "NULL"
  uniqueCount: "NULL"
}

arithmeticToSqlOp = {
  add:      '+'
  subtract: '-'
  multiply: '*'
  divide:   '/'
}

directionMap = {
  ascending:  'ASC'
  descending: 'DESC'
}

class SQLQueryBuilder
  constructor: ({datasetToTable}) ->
    throw new Error("must have datasetToTable mapping") unless typeof datasetToTable is 'object'

    @commonSplitSelectParts = []
    @commonApplySelectParts = []

    @datasets = []
    @datasetParts = {}
    for dataset, table of datasetToTable
      @datasets.push(dataset)
      @datasetParts[dataset] = {
        splitSelectParts: []
        applySelectParts: []
        fromWherePart: @escapeAttribute(table)
        groupByParts: []
      }

    @orderByPart = null
    @limitPart = null

  escapeAttribute: (attribute) ->
    # ToDo: make this work better
    return if isNaN(attribute) then "`#{attribute}`" else String(attribute)

  escapeValue: (value) ->
    return "\"#{value}\"" # ToDo: make this actually work in general

  dateToSQL: (date) ->
    return date.toISOString()
      .replace('T', ' ')
      .replace(/\.\d\d\dZ$/, '') # remove millis
      .replace(' 00:00:00', '') # remove time if 0

  filterToSQL: (filter) ->
    switch filter.type
      when 'true'
        "1 = 1"

      when 'false'
        "1 = 2"

      when 'is'
        "#{@escapeAttribute(filter.attribute)} = #{@escapeValue(filter.value)}"

      when 'in'
        "#{@escapeAttribute(filter.attribute)} IN (#{filter.values.map(@escapeValue, this).join(',')})"

      when 'contains'
        "#{@escapeAttribute(filter.attribute)} LIKE \"%#{filter.value}%\"" # ToDo: escape to prevent SQL injection

      when 'match'
        "#{@escapeAttribute(filter.attribute)} REGEXP '#{filter.expression}'"

      when 'within'
        attribute = @escapeAttribute(filter.attribute)
        [r0, r1] = filter.range
        if isInstanceOf(r0, Date) and isInstanceOf(r1, Date)
          "'#{@dateToSQL(r0)}' <= #{attribute} AND #{attribute} < '#{@dateToSQL(r1)}'"
        else
          "#{r0} <= #{attribute} AND #{attribute} < #{r1}"

      when 'not'
        "NOT (#{@filterToSQL(filter.filter)})"

      when 'and'
        '(' + filter.filters.map(@filterToSQL, this).join(') AND (') + ')'

      when 'or'
        '(' + filter.filters.map(@filterToSQL, this).join(') OR (') + ')'

      else
        throw new Error("filter type '#{filter.type}' unsupported by driver")

  addFilters: (filtersByDataset) ->
    for dataset, datasetPart of @datasetParts
      filter = filtersByDataset[dataset]
      throw new Error("must have filter for dataset '#{dataset}'") unless filter
      continue if filter.type is 'true'
      datasetPart.fromWherePart += " WHERE #{@filterToSQL(filter)}"
    return this

  timeBucketing: {
    'PT1S': {
      select: '%Y-%m-%dT%H:%i:%SZ'
      group: '%Y-%m-%dT%H:%i:%SZ'
    }
    'PT1M': {
      select: '%Y-%m-%dT%H:%i:00Z'
      group: '%Y-%m-%dT%H:%i'
    }
    'PT1H': {
      select: '%Y-%m-%dT%H:00:00Z'
      group: '%Y-%m-%dT%H'
    }
    'P1D': {
      select: '%Y-%m-%dT00:00:00Z'
      group: '%Y-%m-%d'
    }
    'P1W': {
      select: '%Y-%m-%dT00:00:00Z' # wrong
      group: '%Y-%m/%u'
    }
    'P1M': {
      select: '%Y-%m-00T00:00:00Z'
      group: '%Y-%m'
    }
    'P1Y': {
      select: '%Y-00-00T00:00:00Z'
      group: '%Y'
    }
  }

  splitToSQL: (split, name) ->
    switch split.bucket
      when 'identity'
        groupByPart = @escapeAttribute(split.attribute)
        return {
          selectPart: "#{groupByPart} AS `#{name}`"
          groupByPart
        }

      when 'continuous'
        groupByPart = driverUtil.continuousFloorExpresion({
          variable: @escapeAttribute(split.attribute)
          floorFn: "FLOOR"
          size: split.size
          offset: split.offset
        })
        return {
          selectPart: "#{groupByPart} AS `#{name}`"
          groupByPart
        }

      when 'timePeriod'
        bucketSpec = @timeBucketing[split.period]
        throw new Error("unsupported timePeriod period '#{split.period}'") unless bucketSpec

        bucketTimezone = split.timezone or 'Etc/UTC' # ToDo: move this to condense query
        if split.timezone is 'Etc/UTC'
          sqlAttribute = @escapeAttribute(split.attribute)
        else
          # Assume db is in +0:00 so that we don't have to worry about DATETIME vs. TIMESTAMP
          # To use non-offset timezone, one needs to set up time_zone table in the db
          # See https://dev.mysql.com/doc/refman/5.5/en/time-zone-support.html
          sqlAttribute = "CONVERT_TZ(#{@escapeAttribute(split.attribute)}, '+0:00', #{bucketTimezone})"

        return {
          selectPart: "DATE_FORMAT(#{sqlAttribute}, '#{bucketSpec.select}') AS `#{name}`"
          groupByPart: "DATE_FORMAT(#{sqlAttribute}, '#{bucketSpec.group}')"
        }

      when 'tuple'
        parts = split.splits.map(@splitToSQL, this)
        return {
          selectPart:  parts.map((part) -> part.selectPart).join(', ')
          groupByPart: parts.map((part) -> part.groupByPart).join(', ')
        }

      else
        throw new Error("bucket '#{split.bucket}' unsupported by driver")
    return

  addSplit: (split) ->
    throw new TypeError("split must be a FacetSplit") unless isInstanceOf(split, FacetSplit)
    splits = if split.bucket is 'parallel' then split.splits else [split]
    @commonSplitSelectParts.push("`#{split.name}`")
    for subSplit in splits
      datasetPart = @datasetParts[subSplit.getDataset()]
      { selectPart, groupByPart } = @splitToSQL(subSplit, split.name)
      datasetPart.splitSelectParts.push(selectPart)
      datasetPart.groupByParts.push(groupByPart)
    return this

  applyToSQLExpresion: (apply) ->
    if apply.aggregate
      switch apply.aggregate
        when 'constant'
          applyStr = @escapeAttribute(apply.value)

        when 'count', 'sum', 'average', 'min', 'max', 'uniqueCount'
          expresion = if apply.aggregate is 'count' then '1' else @escapeAttribute(apply.attribute)
          if apply.filter
            zero = aggregateToZero[apply.aggregate]
            expresion = "IF(#{@filterToSQL(apply.filter)}, #{expresion}, #{zero})"
          applyStr = aggregateToSqlFn[apply.aggregate](expresion)

        when 'quantile'
          throw new Error("not implemented yet") # ToDo

        else
          throw new Error("unsupported aggregate '#{apply.aggregate}'")

      return applyStr

    sqlOp = arithmeticToSqlOp[apply.arithmetic]
    throw new Error("unsupported arithmetic '#{apply.arithmetic}'") unless sqlOp
    [op1SQL, op2SQL] = apply.operands.map(@applyToSQLExpresion, this)
    applyStr = "(#{op1SQL} #{sqlOp} #{op2SQL})"
    return applyStr


  applyToSQL: (apply) ->
    return "#{@applyToSQLExpresion(apply)} AS `#{apply.name}`"


  addApplies: (applies) ->
    sqlProcessorScheme = {
      constant: ({value}) -> "#{value}"
      getter: ({name}) -> "#{name}"
      arithmetic: (arithmetic, lhs, rhs) ->
        sqlOp = arithmeticToSqlOp[arithmetic]
        throw new Error('unknown arithmetic') unless sqlOp
        return "(IFNULL(#{lhs}, 0) #{sqlOp} IFNULL(#{rhs}, 0))"
      finish: (name, getter) -> "#{getter} AS `#{name}`"
    }

    applySimplifier = new ApplySimplifier({
      postProcessorScheme: sqlProcessorScheme
    })
    applySimplifier.addApplies(applies)

    appliesByDataset = applySimplifier.getSimpleAppliesByDataset()
    postProcessors = applySimplifier.getPostProcessors()

    @commonApplySelectParts = postProcessors
    for dataset, datasetApplies of appliesByDataset
      @datasetParts[dataset].applySelectParts = datasetApplies.map(@applyToSQL, this)

    return this

  addSort: (sort) ->
    return unless sort
    sqlDirection = directionMap[sort.direction]
    switch sort.compare
      when 'natural'
        @orderByPart = "ORDER BY #{@escapeAttribute(sort.prop)}"
        @orderByPart += " #{sqlDirection}"

      when 'caseInsensetive'
        throw new Error("not implemented yet (ToDo)")

      else
        throw new Error("compare '#{sort.compare}' unsupported by driver")

  addCombine: (combine) ->
    throw new TypeError("combine must be a FacetCombine") unless isInstanceOf(combine, FacetCombine)
    switch combine.method
      when 'slice'
        sort = combine.sort
        @addSort(sort) if sort

        limit = combine.limit
        if limit?
          @limitPart = "LIMIT #{limit}"

      when 'matrix'
        sort = combine.sort
        @addSort(sort) if sort

        # ToDo: address limits

      else
        throw new Error("method '#{combine.method}' unsupported by driver")

    return this

  getQueryForDataset: (dataset, topLevel) ->
    datasetPart = @datasetParts[dataset]
    selectParts = [
      datasetPart.splitSelectParts
      datasetPart.applySelectParts
    ]
    selectParts.push(@commonApplySelectParts) if topLevel
    selectParts = driverUtil.flatten(selectParts)
    return null unless selectParts.length
    select = selectParts.join(', ')
    groupBy = datasetPart.groupByParts.join(', ') or '""'
    return "SELECT #{select} FROM #{datasetPart.fromWherePart} GROUP BY #{groupBy}"

  getQuery: ->
    if @datasets.length > 1
      partials = @datasets.map(((dataset) ->
        selectParts = [].concat(
          @commonSplitSelectParts.map((commonSplitSelectPart) -> "`#{dataset}`.#{commonSplitSelectPart}")
          @commonApplySelectParts
        )
        return null unless selectParts.length
        select = selectParts.join(',\n    ')
        partialQuery = [
          "SELECT #{select}"
          'FROM'
        ]
        innerDataset = dataset
        datasetPart = @datasetParts[innerDataset]
        partialQuery.push(  "  (#{@getQueryForDataset(innerDataset)}) AS `#{innerDataset}`")
        for innerDataset in @datasets
          continue if innerDataset is dataset
          datasetPart = @datasetParts[innerDataset]
          partialQuery.push("LEFT JOIN")
          partialQuery.push("  (#{@getQueryForDataset(innerDataset)}) AS `#{innerDataset}`")
          partialQuery.push("USING(#{@commonSplitSelectParts.join(', ')})")

        return '  ' + partialQuery.join('\n  ')
      ), this)
      return null unless partials.every(Boolean)
      query = [partials.join('\nUNION\n')]
    else
      queryForOnlyDataset = @getQueryForDataset(@datasets[0], true)
      return null unless queryForOnlyDataset
      query = [queryForOnlyDataset]

    query.push(@orderByPart) if @orderByPart
    query.push(@limitPart) if @limitPart
    ret = query.join('\n') + ';'
    #console.log 'query', ret
    return ret

condensedCommandToSQL = ({requester, queryBuilder, parentSegment, condensedCommand}, callback) ->
  filtersByDataset = parentSegment._filtersByDataset

  split = condensedCommand.getSplit()
  combine = condensedCommand.getCombine()

  try
    queryBuilder.addFilters(filtersByDataset)
    queryBuilder.addSplit(split) if split
    queryBuilder.addApplies(condensedCommand.applies)
    queryBuilder.addCombine(combine) if combine
  catch e
    callback(e)
    return

  queryToRun = queryBuilder.getQuery()
  if not queryToRun
    newSegmentTree = new SegmentTree({prop: {}})
    newSegmentTree._filtersByDataset = filtersByDataset
    callback(null, [newSegmentTree])
    return

  requester {query: queryToRun}, (err, ds) ->
    if err
      callback(err)
      return

    if split
      splitAttribute = split.attribute
      splitProp = split.name

      if split.bucket is 'continuous'
        splitSize = split.size
        for d in ds
          start = d[splitProp]
          d[splitProp] = [start, start + splitSize]
      else if split.bucket is 'timePeriod'
        timezone = split.timezone or 'Etc/UTC'
        splitDuration = new Duration(split.period)
        for d in ds
          rangeStart = new Date(d[splitProp])
          range = [rangeStart, splitDuration.move(rangeStart, timezone, 1)]
          d[splitProp] = range

      splits = ds.map (prop) ->
        newSegmentTree = new SegmentTree({prop})
        newSegmentTree._filtersByDataset = FacetFilter.andFiltersByDataset(
          filtersByDataset
          split.getFilterByDatasetFor(prop)
        )
        return newSegmentTree
    else
      if ds.length > 1
        callback(new Error('unexpected result'))
        return

      if ds.length is 0
        ds.push(condensedCommand.getZeroProp())

      newSegmentTree = new SegmentTree({prop: ds[0]})
      newSegmentTree._filtersByDataset = filtersByDataset
      splits = [newSegmentTree]

    callback(null, splits)
    return
  return


module.exports = ({requester, table, filter}) ->
  throw new Error("must have a requester") unless typeof requester is 'function'
  throw new Error("must have table") unless typeof table is 'string'

  driver = (request, callback) ->
    try
      throw new Error("request not supplied") unless request
      {context, query} = request
      throw new Error("query not supplied") unless query
      throw new TypeError("query must be a FacetQuery") unless isInstanceOf(query, FacetQuery)
    catch e
      callback(e)
      return

    datasetToTable = {}
    for dataset in query.getDatasets()
      datasetToTable[dataset.name] = table

    init = true
    rootSegment = new SegmentTree({prop: {}})
    rootSegment._filtersByDataset = query.getFiltersByDataset(filter)
    segments = [rootSegment]

    condensedGroups = query.getCondensedCommands()

    querySQL = (condensedCommand, callback) ->
      # do the query in parallel
      QUERY_LIMIT = 10

      if condensedCommand.split?.segmentFilter
        segmentFilterFn = condensedCommand.split.segmentFilter.getFilterFn()
        driverUtil.inPlaceFilter(segments, segmentFilterFn)

      queryFns = async.mapLimit(
        segments
        QUERY_LIMIT
        (parentSegment, callback) ->
          condensedCommandToSQL({
            requester
            queryBuilder: new SQLQueryBuilder({datasetToTable})
            parentSegment
            condensedCommand
          }, (err, splits) ->
            if err
              callback(err)
              return

            if splits is null
              callback(null, null)
              return

            # Make the results into segments and build the tree
            parentSegment.setSplits(splits)
            callback(null, parentSegment.splits)
            return
          )
        (err, results) ->
          if err
            callback(err)
            return

          if results.some((result) -> result is null)
            rootSegment = null
          else
            segments = driverUtil.flatten(results)
            if init
              rootSegment = segments[0]
              init = false

          callback()
          return
      )
      return

    cmdIndex = 0
    async.whilst(
      -> cmdIndex < condensedGroups.length and rootSegment
      (callback) ->
        condencedGroup = condensedGroups[cmdIndex]
        cmdIndex++
        querySQL(condencedGroup, callback)
        return
      (err) ->
        if err
          callback(err)
          return

        callback(null, (rootSegment or new SegmentTree({})).selfClean())
        return
    )

  driver.introspect = (opt, callback) ->
    requester {
      query: "DESCRIBE `#{table}`"
    }, (err, columns) ->
      if err
        callback(err)
        return

      # Field, Type, Null, Key, Default, Extra,
      attributes = columns.map ({Field, Type}) ->
        attribute = { name: Field }
        if Type is 'datetime'
          attribute.time = true
        else if Type.indexOf('varchar(') is 0
          attribute.categorical = true
        else if Type.indexOf('int(') is 0 or Type.indexOf('bigint(') is 0
          attribute.numeric = true
          attribute.integer = true
        else if Type.indexOf('decimal(') is 0
          attribute.numeric = true
        return attribute

      callback(null, attributes)
      return
    return

  return driver
