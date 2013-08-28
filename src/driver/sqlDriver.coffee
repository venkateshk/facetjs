`(typeof window === 'undefined' ? {} : window)['sqlDriver'] = (function(module, require){"use strict"; var exports = module.exports`

async = require('async')
driverUtil = require('./driverUtil')
{FacetFilter, TrueFilter, FacetSplit, FacetApply, FacetCombine, FacetQuery, AndFilter} = require('./query')

# -----------------------------------------------------

andFilters = (filter1, filter2) ->
  return new AndFilter([filter1, filter2]).simplify()

class SQLQueryBuilder
  constructor: (table) ->
    throw new Error("must have table") unless typeof table is 'string'
    @selectParts = []
    @groupByParts = []
    @filterPart = null
    @fromPart = "FROM #{@escapeAttribute(table)}"
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
        if r0 instanceof Date and r1 instanceof Date
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

  addFilter: (filter) ->
    return unless filter
    @filterPart = "WHERE #{@filterToSQL(filter)}"
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
    'P1M': {
      select: '%Y-%m-00T00:00:00Z'
      group: '%Y-%m'
    }
    'P1Y': {
      select: '%Y-00-00T00:00:00Z'
      group: '%Y'
    }
  }

  splitToSQL: (split) ->
    switch split.bucket
      when 'identity'
        groupByPart = @escapeAttribute(split.attribute)
        return {
          selectPart: "#{groupByPart} AS \"#{split.name}\""
          groupByPart
        }

      when 'continuous'
        groupByPart = @escapeAttribute(split.attribute)
        groupByPart = "(#{groupByPart} + #{split.offset})" if split.offset isnt 0
        groupByPart = "#{groupByPart} / #{split.size}" if split.size isnt 1
        groupByPart = "FLOOR(#{groupByPart})"
        groupByPart = "#{groupByPart} * #{split.size}" if split.size isnt 1
        groupByPart = "#{groupByPart} - #{split.offset}" if split.offset isnt 0
        return {
          selectPart: "#{groupByPart} AS \"#{split.name}\""
          groupByPart
        }

      when 'timeDuration'
        throw new Error("not implemented yet (ToDo)")

      when 'timePeriod'
        bucketPeriod = split.period
        bucketSpec = @timeBucketing[bucketPeriod]

        if not bucketSpec
          throw new Error("unsupported timePeriod bucketing period '#{bucketPeriod}'")

        bucketTimezone = split.timezone or 'Etc/UTC' # ToDo: move this to condense query
        if split.timezone is 'Etc/UTC'
          sqlAttribute = @escapeAttribute(split.attribute)
        else
          # Assume db is in +0:00 so that we don't have to worry about DATETIME vs. TIMESTAMP
          # To use non-offset timezone, one needs to set up time_zone table in the db
          # See https://dev.mysql.com/doc/refman/5.5/en/time-zone-support.html
          sqlAttribute = "CONVERT_TZ(#{@escapeAttribute(split.attribute)}, '+0:00', #{bucketTimezone})"

        return {
          selectPart: "DATE_FORMAT(#{sqlAttribute}, '#{bucketSpec.select}') AS \"#{split.name}\""
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
    throw new TypeError("split must be a FacetSplit") unless split instanceof FacetSplit
    @split = split
    { selectPart, groupByPart } = @splitToSQL(split)
    @selectParts.push(selectPart)
    @groupByParts.push(groupByPart)
    return this

  applyToSQL: do ->
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
    return (apply) ->
      throw new TypeError("apply must be a FacetApply") unless apply instanceof FacetApply
      if apply.aggregate
        switch apply.aggregate
          when 'constant'
            @escapeAttribute(apply.value)

          when 'count', 'sum', 'average', 'min', 'max', 'uniqueCount'
            expresion = if apply.aggregate is 'count' then '1' else @escapeAttribute(apply.attribute)
            if apply.filter
              zero = aggregateToZero[apply.aggregate]
              expresion = "IF(#{@filterToSQL(apply.filter)}, #{expresion}, #{zero})"
            aggregateToSqlFn[apply.aggregate](expresion)

          when 'quantile'
            throw new Error("not implemented yet") # ToDo

          else
            throw new Error("unsupported aggregate '#{apply.aggregate}'")

      else if apply.arithmetic
        sqlOp = arithmeticToSqlOp[apply.arithmetic]
        if sqlOp
          return "(#{@applyToSQL(apply.operands[0])} #{sqlOp} #{@applyToSQL(apply.operands[1])})"
        else
          throw new Error("unsupported arithmetic '#{apply.arithmetic}'")

      else
        throw new Error("must have an aggregate or an arithmetic")


  addApply: (apply) ->
    @selectParts.push("#{@applyToSQL(apply)} AS \"#{apply.name}\"")
    return this

  directionMap: {
    ascending:  'ASC'
    descending: 'DESC'
  }

  addSort: (sort) ->
    return unless sort
    sqlDirection = @directionMap[sort.direction]
    switch sort.compare
      when 'natural'
        @orderByPart = "ORDER BY #{@escapeAttribute(sort.prop)}"

        # if @split?.bucket is 'identity'
        #   @orderByPart += " COLLATE utf8_bin"

        @orderByPart += " #{sqlDirection}"

      when 'caseInsensetive'
        throw new Error("not implemented yet (ToDo)")

      else
        throw new Error("compare '#{sort.compare}' unsupported by driver")

  addCombine: (combine) ->
    throw new TypeError("combine must be a FacetCombine") unless combine instanceof FacetCombine
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

  getQuery: ->
    return null unless @selectParts.length
    query = [
      'SELECT'
      @selectParts.join(', ')
      @fromPart
    ]

    query.push(@filterPart) if @filterPart
    if @groupByParts.length
      query.push('GROUP BY ' + @groupByParts.join(', '))
    else
      query.push('GROUP BY ""')
    query.push(@orderByPart) if @orderByPart
    query.push(@limitPart) if @limitPart

    return query.join(' ') + ';'


condensedQueryToSQL = ({requester, table, filter, condensedQuery}, callback) ->
  sqlQuery = new SQLQueryBuilder(table)

  try
    sqlQuery.addFilter(filter)

    # split
    split = condensedQuery.split
    if split
      sqlQuery.addSplit(split)

    # apply
    for apply in condensedQuery.applies
      sqlQuery.addApply(apply)

    # combine
    combine = condensedQuery.combine
    if combine
      sqlQuery.addCombine(combine)
  catch e
    callback(e)
    return

  queryToRun = sqlQuery.getQuery()
  if not queryToRun
    callback(null, [{ prop: {}, _filter: filter }])
    return

  requester {query: queryToRun}, (err, ds) ->
    if err
      callback(err)
      return

    # ToDo: implement actual timezones
    periodMap = {
      'PT1S': 1000
      'PT1M': 60 * 1000
      'PT1H': 60 * 60 * 1000
      'P1D' : 24 * 60 * 60 * 1000
    }

    if condensedQuery.split
      splitAttribute = condensedQuery.split.attribute
      splitProp = condensedQuery.split.name

      if condensedQuery.split.bucket is 'continuous'
        splitSize = condensedQuery.split.size
        for d in ds
          start = d[splitProp]
          d[splitProp] = [start, start + splitSize]
      else if condensedQuery.split.bucket is 'timePeriod'
        period = periodMap[condensedQuery.split.period]
        for d in ds
          rangeStart = new Date(d[splitProp])
          range = [rangeStart, new Date(rangeStart.valueOf() + period)]
          d[splitProp] = range

      splits = ds.map (prop) -> {
        prop
        _filter: andFilters(filter, condensedQuery.split.getFilterFor(prop))
      }
    else
      splits = ds.map (prop) -> {
        prop
        _filter: filter
      }

    callback(null, if splits.length then splits else null)
    return
  return


module.exports = ({requester, table, filter}) ->
  throw new Error("must have a requester") unless typeof requester is 'function'
  throw new Error("must have table") unless typeof table is 'string'
  filter ?= new TrueFilter()
  throw new TypeError("filter should be a FacetFilter") unless filter instanceof FacetFilter

  return (request, callback) ->
    try
      throw new Error("request not supplied") unless request
      {context, query} = request
      throw new Error("query not supplied") unless query
      throw new TypeError("query must be a FacetQuery") unless query instanceof FacetQuery
    catch e
      callback(e)
      return

    init = true
    rootSegment = {
      parent: null
      _filter: if filter then andFilters(filter, query.getFilter()) else query.getFilter()
    }
    segments = [rootSegment]

    condensedGroups = query.getGroups()

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
          condensedQueryToSQL({
            requester
            table
            filter: parentSegment._filter
            condensedQuery: condensedCommand
          }, (err, splits) ->
            if err
              callback(err)
              return

            if splits is null
              callback(null, null)
              return

            # Make the results into segments and build the tree
            parentSegment.splits = splits

            for split in splits
              split.parent = parentSegment

            callback(null, splits)
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

        callback(null, driverUtil.cleanSegments(rootSegment or {}))
        return
    )


# -----------------------------------------------------
# Handle commonJS crap
`return module.exports; }).call(this,
  (typeof module === 'undefined' ? {exports: {}} : module),
  (typeof require === 'undefined' ? function (modulePath, altPath) {
    if (altPath) return window[altPath];
    var moduleParts = modulePath.split('/');
    return window[moduleParts[moduleParts.length - 1]];
  } : require)
)`
