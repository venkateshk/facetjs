`(typeof window === 'undefined' ? {} : window)['sqlDriver'] = (function(module, require){"use strict"; var exports = module.exports`

async = require('async')
driverUtil = require('./driverUtil')

# -----------------------------------------------------

makeFilter = (attribute, value) ->
  if Array.isArray(value)
    return { type: 'within', attribute, range: value }
  else
    return { type: 'is', attribute, value }

andFilters = (filters...) ->
  filters = filters.filter((filter) -> filter?)
  switch filters.length
    when 0
      return null
    when 1
      return filters[0]
    else
      return { type: 'and',  filters }

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
      .replace('T',   ' ')
      .replace(/\.\d\d\dZ$/, '') # remove millis
      .replace(' 00:00:00', '') # remove time if 0

  filterToSQL: (filter) ->
    switch filter.type
      when 'is'
        "#{@escapeAttribute(filter.attribute)} = #{@escapeValue(filter.value)}"

      when 'in'
        "#{@escapeAttribute(filter.attribute)} in (#{filter.values.map(@escapeValue, this).join(',')})"

      when 'fragments'
        throw "todo"

      when 'match'
        "#{@escapeAttribute(filter.attribute)} REGEXP '#{filter.expression}'"

      when 'within'
        attribute = @escapeAttribute(filter.attribute)
        [r0, r1] = filter.range
        if (typeof r0 is 'string' and typeof r1 is 'string') or (r0 instanceof Date and r1 instanceof Date)
          r0 = new Date(r0)
          r1 = new Date(r1)
          throw new Error("invalid dates") if isNaN(r0) or isNaN(r1)
          "'#{@dateToSQL(r0)}' <= #{attribute} AND #{attribute} < '#{@dateToSQL(r1)}'"
        else if typeof r0 is 'number' and typeof r1 is 'number'
          "#{r0} <= #{attribute} AND #{attribute} < #{r1}"
        else
          throw new Error("unsuported range in within filter")


      when 'not'
        "NOT (#{@filterToSQL(filter.filter)})"

      when 'and'
        '(' + filter.filters.map(@filterToSQL, this).join(') AND (') + ')'

      when 'or'
        '(' + filter.filters.map(@filterToSQL, this).join(') OR (') + ')'

      else
        throw new Error("unknown filter type '#{filter.type}'")

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

  addSplit: (split) ->
    switch split.bucket
      when 'identity'
        selectPart = @escapeAttribute(split.attribute)
        groupByPart = @escapeAttribute(split.attribute)

      when 'continuous'
        floorStr = @escapeAttribute(split.attribute)
        floorStr = "(#{floorStr} + #{split.offset})" if split.offset isnt 0
        floorStr = "#{floorStr} / #{split.size}" if split.size isnt 1
        floorStr = "FLOOR(#{floorStr})"
        floorStr = "#{floorStr} * #{split.size}" if split.size isnt 1
        floorStr = "#{floorStr} - #{split.offset}" if split.offset isnt 0
        selectPart = floorStr
        groupByPart = floorStr

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

        selectPart = "DATE_FORMAT(#{sqlAttribute}, '#{bucketSpec.select}')"
        groupByPart = "DATE_FORMAT(#{sqlAttribute}, '#{bucketSpec.group}')"

      else
        throw new Error("unsupported bucketing policy '#{split.bucket}'")

    @selectParts.push("#{selectPart} AS \"#{split.name}\"")
    @groupByParts.push("#{groupByPart}")
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
    arithmeticToSqlOp = {
      add:      '+'
      subtract: '-'
      multiply: '*'
      divide:   '/'
    }
    return (apply) ->
      if apply.aggregate
        switch apply.aggregate
          when 'constant'
            @escapeAttribute(apply.value)

          when 'count', 'sum', 'average', 'min', 'max', 'uniqueCount'
            expresion = if apply.aggregate is 'count' then '1' else @escapeAttribute(apply.attribute)
            if apply.filter
              expresion = "IF(#{@filterToSQL(apply.filter)}, #{expresion}, NULL)"
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
    sqlDirection = @directionMap[sort.direction]
    switch sort.compare
      when 'natural'
        @orderByPart = "ORDER BY #{@escapeAttribute(sort.prop)} #{sqlDirection}"

      when 'caseInsensetive'
        throw new Error("not implemented yet (ToDo)")

      else
        throw new Error("unsupported compare '#{sort.compare}'")

    return this

  addLimit: (limit) ->
    @limitPart = "LIMIT #{limit}"
    return this

  getQuery: ->
    return null unless @selectParts.length
    query = [
      'SELECT'
      @selectParts.join(', ')
      @fromPart
    ]

    query.push(@filterPart) if @filterPart
    query.push('GROUP BY ' + @groupByParts.join(', ')) if @groupByParts.length
    query.push(@orderByPart) if @orderByPart
    query.push(@limitPart) if @limitPart

    return query.join(' ') + ';'


condensedQueryToSQL = ({requester, table, filter, condensedQuery}, callback) ->
  sqlQuery = new SQLQueryBuilder(table)

  filter = andFilters(filter, condensedQuery.filter)
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
      if combine.sort
        sqlQuery.addSort(combine.sort)

      if combine.limit?
        sqlQuery.addLimit(combine.limit)
  catch e
    callback(e)
    return

  queryToRun = sqlQuery.getQuery()
  if not queryToRun
    callback(null, [{ prop: {}, _filter: filter }])
    return

  requester queryToRun, (err, ds) ->
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
        _filter: andFilters(filter, makeFilter(splitAttribute, prop[splitProp]))
      }
    else
      splits = ds.map (prop) -> {
        prop
        _filter: filter
      }

    callback(null, splits)
    return
  return


module.exports = ({requester, table, filter}) -> (query, callback) ->
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
          filter: if parentSegment then parentSegment._filter else filter
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
`return module.exports; }).call(this,
  (typeof module === 'undefined' ? {exports: {}} : module),
  (typeof require === 'undefined' ? function (modulePath) {
    var moduleParts = modulePath.split('/');
    return window[moduleParts[moduleParts.length - 1]];
  } : require)
)`
