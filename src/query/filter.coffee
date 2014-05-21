{specialJoin, getValueOf, find, dummyObject} = require('./common')

smaller = (a, b) -> if a < b then a else b

larger  = (a, b) -> if a < b then b else a

rangesIntersect = (range1, range2) ->
  if range2[1] < range1[0] or range2[0] > range1[1]
    return false
  else
    return range1[0] <= range2[1] and range2[0] <= range1[1]


union = (sets...) ->
  ret = []
  seen = {}
  for set in sets
    for value in set
      continue if seen[value]
      seen[value] = true
      ret.push(value)
  return ret

intersection = (set, sets...) ->
  return set.filter (value) ->
    for s in sets
      return false unless value in s

    return true

compare = (a, b) ->
  return -1 if a < b
  return +1 if a > b
  return 0

arrayCompare = (arr1, arr2) ->
  arr1Length = arr1.length
  arr2Length = arr2.length
  lengthDiff = arr1Length - arr2Length
  return lengthDiff if lengthDiff isnt 0 or arr1Length is 0

  # Left with same length non-empty arrays
  # Do a 'dictionary' compare
  for x1, i in arr1
    diff = compare(x1, arr2[i])
    return diff if diff isnt 0

  return 0


filterSortTypePresedence = {
  'true': -2
  'false': -1
  'within': 0
  'in': 0
  'not in': 0
  'contains': 0
  'match': 0
  'not': 1
  'and': 2
  'or': 3
}

filterSortTypeSubPresedence = {
  'within': 0
  'in': 1
  'not in': 2
  'contains': 3
  'match': 4
}

defaultStringifier = {
  stringify: (filter) ->
    throw new Error('stringifier needs FacetFilter') unless filter instanceof FacetFilter
    switch filter.type
      when 'true'
        return "None"
      when 'false'
        return "Nothing"
      when 'is'
        return "#{filter.attribute} is #{filter.value}"
      when 'in'
        switch filter.values.length
          when 0 then return "Nothing"
          when 1 then return "#{filter.attribute} is #{filter.values[0]}"
          when 2 then return "#{filter.attribute} is either #{filter.values[0]} or #{filter.values[1]}"
          else return "#{filter.attribute} is one of: #{specialJoin(filter.values, ', ', ', or ')}"
      when 'contains'
        return "#{filter.attribute} contains '#{filter.value}'"
      when 'match'
        return "#{filter.attribute} matches /#{filter.expression}/"
      when 'or'
        if filter.filters.length > 1
          return "(#{filter.filters.join(') or (')})"
        else
          return String(filter.filters[0])
      when 'within'
        [r0, r1] = filter.range
        r0 = r0.toISOString() if r0 instanceof Date
        r1 = r1.toISOString() if r1 instanceof Date
        return "#{filter.attribute} is within #{r0} and #{r1}"
      when 'not'
        return "not (#{filter.filter})"
      when 'and'
        if filter.filters.length > 1
          return "(#{filter.filters.join(') and (')})"
        else
          return String(filter.filters[0])
      else
        throw new Error("unknown filter type #{filter.type}")
}

class FacetFilter
  @defaultStringifier = defaultStringifier

  @compare = (filter1, filter2) ->
    filter1SortType = filter1._getSortType()
    filter2SortType = filter2._getSortType()

    presedence1 = filterSortTypePresedence[filter1SortType]
    presedence2 = filterSortTypePresedence[filter2SortType]
    presedenceDiff = presedence1 - presedence2
    return presedenceDiff if presedenceDiff isnt 0 or presedence1 > 0

    # We are left with 'within', 'is', 'in', 'contains', 'match' at this point
    # Sort by attribute
    attributeDiff = compare(filter1.attribute, filter2.attribute)
    return attributeDiff if attributeDiff isnt 0

    # Same attribute, sort by subPresedence
    presedenceDiff = filterSortTypeSubPresedence[filter1SortType] - filterSortTypeSubPresedence[filter2SortType]
    return presedenceDiff if presedenceDiff isnt 0

    # Same attribute, same type, sort by specifics
    switch filter1SortType
      when 'within'
        return arrayCompare(filter1.range, filter2.range)

      when 'in', 'not in'
        return arrayCompare(filter1._getInValues(), filter2._getInValues())

      when 'contains'
        return compare(filter1.value, filter2.value)

      when 'match'
        return compare(filter1.expression, filter2.expression)

    return 0


  # set Stringifier strategy for FacetFilter class
  # Interface Stringifier
  #   #
  #   # @param {FacetFilter} filter
  #   # @return {String} string representation of the given filter
  #   #
  #   stringify: (filter) ->
  #     <some function>
  #
  # @param {Stringifier}
  # @return {FacetFilter} this
  #
  @setStringifier = (@defaultStringifier) -> return this

  # set Stringifier strategy for instances of FacetFilter
  # Interface Stringifier
  #   #
  #   # @param {FacetFilter} filter
  #   # @return {String} string representation of the given filter
  #   #
  #   stringify: (filter) ->
  #     <some function>
  #
  # @param {Stringifier}
  # @return {FacetFilter} this
  #
  setStringifier: (@stringifier) -> return this

  constructor: ({@type, @dataset}, dummy) ->
    throw new TypeError("can not call `new FacetFilter` directly use FacetFilter.fromSpec instead") unless dummy is dummyObject

  _ensureType: (filterType) ->
    if not @type
      @type = filterType # Set the type if it is so far undefined
      return
    if @type isnt filterType
      throw new TypeError("incorrect filter type '#{@type}' (needs to be: '#{filterType}')")
    return

  _validateAttribute: ->
    if typeof @attribute isnt 'string'
      throw new TypeError("attribute must be a string")

  _getSortType: ->
    return @type

  valueOf: ->
    filter = { type: @type }
    filter.dataset = @dataset if @dataset
    return filter

  toJSON: -> @valueOf.apply(this, arguments)

  isEqual: (other) ->
    return Boolean(other) and @type is other.type and @attribute is other.attribute

  getComplexity: ->
    return 1

  # Reduces a filter into a (potentially) simpler form the input is never modified
  # Specifically this function:
  # - flattens nested ANDs
  # - flattens nested ORs
  # - sorts lists of filters within an AND / OR by attribute
  simplify: ->
    return this # Base simplify is to do nothing

  # Separate filters into ones with a certain attribute and ones without
  # Such that the WithoutFilter AND WithFilter are semantically equivalent to the original filter
  #
  # @param {FacetFilter} filter - the filter to separate
  # @param {String} attribute - the attribute which to separate out
  # @return {null|Array} null|[WithoutFilter, WithFilter] - the separated filters
  extractFilterByAttribute: (attribute) ->
    throw new TypeError("must have an attribute") unless typeof attribute is 'string'
    if not @attribute or @attribute isnt attribute
      return [this, new TrueFilter()]
    else
      return [new TrueFilter(), this]

  getDataset: ->
    return @dataset or 'main'

  toString: ->
    stringifier = @stringifier or FacetFilter.defaultStringifier
    return stringifier.stringify(this)

  toHash: ->
    throw new Error('can not call this directly')


class TrueFilter extends FacetFilter
  constructor: ->
    super(arguments[0] or {}, dummyObject)
    @_ensureType('true')

  getFilterFn: ->
    return -> true

  toHash: ->
    return 'T'



class FalseFilter extends FacetFilter
  constructor: ->
    super(arguments[0] or {}, dummyObject)
    @_ensureType('false')

  getFilterFn: ->
    return -> false

  toHash: ->
    return 'F'


class IsFilter extends FacetFilter
  constructor: ({@attribute, @value}) ->
    super(arguments[0], dummyObject)
    @_ensureType('is')
    @_validateAttribute()

  _getSortType: ->
    return 'in'

  _getInValues: ->
    return [@value]

  valueOf: ->
    filter = super()
    filter.attribute = @attribute
    filter.value = @value
    return filter

  isEqual: (other) ->
    return super(other) and other.value is @value

  getFilterFn: ->
    attribute = @attribute
    value = @value
    return (d) -> d[attribute] is value

  toHash: ->
    return "IS:#{@attribute}:#{@value}"



class InFilter extends FacetFilter
  constructor: ({@attribute, @values}) ->
    super(arguments[0], dummyObject)
    @_ensureType('in')
    @_validateAttribute()
    throw new TypeError('`values` must be an array') unless Array.isArray(@values)

  _getInValues: ->
    return @values

  valueOf: ->
    filter = super()
    filter.attribute = @attribute
    filter.values = @values
    return filter

  simplify: ->
    return this if @simple

    vs = union(@values)
    switch vs.length
      when 0
        return new FalseFilter()

      when 1
        return new IsFilter({ attribute: @attribute, value: vs[0] })

      else
        vs.sort()
        simpleFilter = new InFilter({ attribute: @attribute, values: vs })
        simpleFilter.simple = true
        return simpleFilter

  isEqual: (other) ->
    return super(other) and other.values.join(';') is @values.join(';')

  getFilterFn: ->
    attribute = @attribute
    values = @values
    return (d) -> d[attribute] in values

  toHash: ->
    return "IN:#{@attribute}:#{@values.join(';')}"



class ContainsFilter extends FacetFilter
  constructor: ({@attribute, @value}) ->
    super(arguments[0], dummyObject)
    @_ensureType('contains')
    @_validateAttribute()
    throw new TypeError('contains must be a string') unless typeof @value is 'string'

  valueOf: ->
    filter = super()
    filter.attribute = @attribute
    filter.value = @value
    return filter

  isEqual: (other) ->
    return super(other) and other.value is @value

  getFilterFn: ->
    attribute = @attribute
    value = @value
    return (d) -> String(d[attribute]).indexOf(value) isnt -1

  toHash: ->
    return "C:#{@attribute}:#{@value}"



class MatchFilter extends FacetFilter
  constructor: ({@attribute, @expression}) ->
    super(arguments[0], dummyObject)
    @_ensureType('match')
    @_validateAttribute()
    throw new Error('must have an expression') unless @expression
    try
      new RegExp(@expression)
    catch e
      throw new Error('expression must be a valid regular expression')

  valueOf: ->
    filter = super()
    filter.attribute = @attribute
    filter.expression = @expression
    return filter

  isEqual: (other) ->
    return super(other) and other.expression is @expression

  getFilterFn: ->
    attribute = @attribute
    expression = new RegExp(@expression)
    return (d) -> expression.test(d[attribute])

  toHash: ->
    return "F:#{@attribute}:#{@expression}"



class WithinFilter extends FacetFilter
  constructor: ({@attribute, @range}) ->
    super(arguments[0], dummyObject)
    @_ensureType('within')
    @_validateAttribute()
    throw new TypeError('range must be an array of length 2') unless Array.isArray(@range) and @range.length is 2
    [r0, r1] = @range
    if typeof r0 is 'string' and typeof r1 is 'string'
      @range = [new Date(r0), new Date(r1)]

    throw new Error('invalid range') if isNaN(@range[0]) or isNaN(@range[1])

  valueOf: ->
    filterSpec = super()
    filterSpec.attribute = @attribute
    filterSpec.range = @range
    return filterSpec

  isEqual: (other) ->
    return super(other) and other.range[0] is @range[0] and other.range[1] is @range[1]

  getFilterFn: ->
    attribute = @attribute
    [r0, r1] = @range
    if r0 instanceof Date
      return (d) -> r0 <= new Date(d[attribute]) < r1
    else
      return (d) -> r0 <= Number(d[attribute]) < r1

  toHash: ->
    return "W:#{@attribute}:#{@range[0].valueOf()}:#{@range[1].valueOf()}"



class NotFilter extends FacetFilter
  constructor: (arg) ->
    if arg not instanceof FacetFilter
      super(arg, dummyObject)
      @filter = FacetFilter.fromSpec(arg.filter)
    else
      @filter = arg
    @_ensureType('not')

  _getSortType: ->
    filterSortType = @filter._getSortType()
    return if filterSortType is 'in' then 'not in' else 'not'

  _getInValues: ->
    return @filter._getInValues()

  valueOf: ->
    filter = super()
    filter.filter = @filter.valueOf()
    return filter

  getComplexity: ->
    return 1 + @filter.getComplexity()

  simplify: ->
    return this if @simple

    switch @filter.type
      when 'true'
        return new FalseFilter()

      when 'false'
        return new TrueFilter()

      when 'not'
        return @filter.filter.simplify()

      when 'and', 'or'
        AndOrConstructor = if @filter.type is 'and' then OrFilter else AndFilter
        return new AndOrConstructor(@filter.filters.map((filter) -> new NotFilter(filter))).simplify()

      else
        simpleFilter = new NotFilter(@filter.simplify())
        simpleFilter.simple = true
        return simpleFilter

  extractFilterByAttribute: (attribute) ->
    throw new TypeError("must have an attribute") unless typeof attribute is 'string'
    return @simplify().extractFilterByAttribute(attribute) unless @simple

    return null unless @filter.attribute # Not sure when this could ever happen in a simple filter
    return if @filter.attribute is attribute then [new TrueFilter(), this] else [this, new TrueFilter()]

  isEqual: (other) ->
    return super(other) and @filter.isEqual(other.filter)

  getFilterFn: ->
    filter = @filter.getFilterFn()
    return (d) -> not filter(d)

  toHash: ->
    return "N(#{@filter.toHash()})"



class AndFilter extends FacetFilter
  constructor: (arg) ->
    if not Array.isArray(arg)
      super(arg, dummyObject)
      throw new TypeError('filters must be an array') unless Array.isArray(arg.filters)
      @filters = arg.filters.map(FacetFilter.fromSpec)
    else
      @filters = arg

    @_ensureType('and')

  valueOf: ->
    filter = super()
    filter.filters = @filters.map(getValueOf)
    return filter

  isEqual: (other) ->
    otherFilters = other.filters
    return super(other) and
           @filters.length is otherFilters.length and
           @filters.every((filter, i) -> filter.isEqual(otherFilters[i]))

  getComplexity: ->
    complexity = 1
    complexity += filter.getComplexity() for filter in @filters
    return complexity

  _mergeFilters: (filter1, filter2) ->
    filter1SortType = filter1._getSortType()
    filter2SortType = filter2._getSortType()

    return new FalseFilter() if filter1SortType is 'false' or filter2SortType is 'false'
    return filter2 if filter1SortType is 'true'
    return filter1 if filter2SortType is 'true'

    return unless filter1.attribute? and (filter1.attribute is filter2.attribute)
    attribute = filter1.attribute

    return filter1 if filter1.isEqual(filter2)

    if filter1SortType isnt filter2SortType
      # if filter1SortType in ['in', 'not in'] and filter2SortType in ['in', 'not in']
      #   ...
      return

    switch filter1SortType
      when 'within'
        return unless rangesIntersect(filter1.range, filter2.range)
        [start1, end1] = filter1.range
        [start2, end2] = filter2.range
        return new WithinFilter({
          attribute
          range: [larger(start1, start2), smaller(end1, end2)]
        })

      when 'in'
        return new InFilter({
          attribute
          values: intersection(filter1._getInValues(), filter2._getInValues())
        }).simplify()

      when 'not in'
        return new NotFilter(new InFilter({
          attribute
          values: intersection(filter1._getInValues(), filter2._getInValues())
        })).simplify()

    return

  simplify: ->
    return this if @simple

    newFilters = []
    for filter in @filters
      filter = filter.simplify()
      if filter.type is 'and'
        Array::push.apply(newFilters, filter.filters)
      else
        newFilters.push(filter)

    newFilters.sort(FacetFilter.compare)

    if newFilters.length > 1
      mergedFilters = []
      acc = newFilters[0]
      i = 1
      while i < newFilters.length
        currentFilter = newFilters[i]
        merged = @_mergeFilters(acc, currentFilter)
        if merged
          acc = merged
        else
          mergedFilters.push(acc)
          acc = currentFilter
        i++
      # Check last filter for being TRUE or FALSE
      return new FalseFilter() if acc.type is 'false'
      mergedFilters.push(acc) unless acc.type is 'true'
      newFilters = mergedFilters

    switch newFilters.length
      when 0
        return new TrueFilter()
      when 1
        return newFilters[0]
      else
        simpleFilter = new AndFilter(newFilters)
        simpleFilter.simple = true
        return simpleFilter

  extractFilterByAttribute: (attribute) ->
    throw new TypeError("must have an attribute") unless typeof attribute is 'string'
    return @simplify().extractFilterByAttribute(attribute) unless @simple

    remainingFilters = []
    extractedFilters = []
    for filter in @filters
      extract = filter.extractFilterByAttribute(attribute)
      return null if extract is null
      remainingFilters.push(extract[0])
      extractedFilters.push(extract[1])

    return [
      new AndFilter(remainingFilters).simplify()
      new AndFilter(extractedFilters).simplify()
    ]

  getFilterFn: ->
    filters = @filters.map((f) -> f.getFilterFn())
    return (d) ->
      for filter in filters
        return false unless filter(d)
      return true

  toHash: ->
    return "(#{@filters.map((filter) -> filter.toHash()).join(')^(')})"



class OrFilter extends FacetFilter
  constructor: (arg) ->
    if not Array.isArray(arg)
      super(arg, dummyObject)
      throw new TypeError('filters must be an array') unless Array.isArray(arg.filters)
      @filters = arg.filters.map(FacetFilter.fromSpec)
    else
      @filters = arg

    @_ensureType('or')

  valueOf: ->
    filter = super()
    filter.filters = @filters.map(getValueOf)
    return filter

  isEqual: (other) ->
    otherFilters = other.filters
    return super(other) and
           @filters.length is otherFilters.length and
           @filters.every((filter, i) -> filter.isEqual(otherFilters[i]))

  getComplexity: ->
    complexity = 1
    complexity += filter.getComplexity() for filter in @filters
    return complexity

  _mergeFilters: (filter1, filter2) ->
    filter1SortType = filter1._getSortType()
    filter2SortType = filter2._getSortType()

    return new TrueFilter() if filter1SortType is 'true' or filter2SortType is 'true'
    return filter2 if filter1SortType is 'false'
    return filter1 if filter2SortType is 'false'

    return unless filter1.attribute? and (filter1.attribute is filter2.attribute)
    attribute = filter1.attribute

    return filter1 if filter1.isEqual(filter2)

    if filter1SortType isnt filter2SortType
      # if filter1SortType in ['in', 'not in'] and filter2SortType in ['in', 'not in']
      #   if filter1SortType is 'in'
      #     inFilter = filter1
      #     notInFilter = filter2
      #   else
      #     inFilter = filter2
      #     notInFilter = filter1

      #   return new InFilter({
      #     attribute
      #     values: difference(inFilter._getInValues(), notInFilter._getInValues())
      #   }).simplify()

      return

    switch filter1SortType
      when 'within'
        if rangesIntersect(filter1.range, filter2.range)
          [start1, end1] = filter1.range
          [start2, end2] = filter2.range
          return new WithinFilter({
            attribute: filter1.attribute
            range: [smaller(start1, start2), larger(end1, end2)]
          })
        else
          return new FalseFilter()

      when 'in'
        return new InFilter({
          attribute
          values: union(filter1._getInValues(), filter2._getInValues())
        }).simplify()

      when 'not in'
        return new NotFilter(new InFilter({
          attribute
          values: union(filter1._getInValues(), filter2._getInValues())
        })).simplify()

    return

  simplify: ->
    return this if @simple

    newFilters = []
    for filter in @filters
      filter = filter.simplify()
      if filter.type is 'or'
        Array::push.apply(newFilters, filter.filters)
      else
        newFilters.push(filter)

    newFilters.sort(FacetFilter.compare)

    if newFilters.length > 1
      mergedFilters = []
      acc = newFilters[0]
      i = 1
      while i < newFilters.length
        currentFilter = newFilters[i]
        merged = @_mergeFilters(acc, currentFilter)
        if merged
          acc = merged
        else
          mergedFilters.push(acc)
          acc = currentFilter
        i++
      # Check last filter for being TRUE or FALSE
      return new TrueFilter() if acc.type is 'true'
      mergedFilters.push(acc) unless acc.type is 'false'
      newFilters = mergedFilters

    switch newFilters.length
      when 0
        return new FalseFilter()
      when 1
        return newFilters[0]
      else
        simpleFilter = new OrFilter(newFilters)
        simpleFilter.simple = true
        return simpleFilter

  extractFilterByAttribute: (attribute) ->
    throw new TypeError("must have an attribute") unless typeof attribute is 'string'
    return @simplify().extractFilterByAttribute(attribute) unless @simple

    hasRemaining = false
    hasExtracted = false
    for filter in @filters
      extracts = filter.extractFilterByAttribute(attribute)
      return null unless extracts
      hasRemaining or= extracts[0].type isnt 'true'
      hasExtracted or= extracts[1].type isnt 'true'

    if hasRemaining
      return if hasExtracted then null else [this, new TrueFilter()]
    else
      throw new Error("something went wrong") unless hasExtracted
      return [new TrueFilter(), this]

  getFilterFn: ->
    filters = @filters.map((f) -> f.getFilterFn())
    return (d) ->
      for filter in filters
        return true if filter(d)
      return false

  toHash: ->
    return "(#{@filters.map((filter) -> filter.toHash()).join(')v(')})"



# Class methods ------------------------

# Computes the diff between sup & sub assumes that sup and sub are either atomic or an AND of atomic filters
FacetFilter.filterDiff = (subFilter, superFilter) ->
  subFilter = subFilter.simplify()
  superFilter = superFilter.simplify()

  subFilters = if subFilter.type is 'true' then [] else if subFilter.type is 'and' then subFilter.filters else [subFilter]
  superFilters = if superFilter.type is 'true' then [] else if superFilter.type is 'and' then superFilter.filters else [superFilter]

  filterInSuperFilter = (filter) ->
    for sf in superFilters
      return true if filter.isEqual(sf)
    return false

  diff = []
  numFoundInSubFilters = 0
  for subFilterFilter in subFilters
    if filterInSuperFilter(subFilterFilter)
      numFoundInSubFilters++
    else
      diff.push(subFilterFilter)

  return if numFoundInSubFilters is superFilters.length then diff else null


FacetFilter.filterSubset = (subFilter, superFilter) ->
  return Boolean(FacetFilter.filterDiff(subFilter, superFilter))


FacetFilter.andFiltersByDataset = (filters1, filters2) ->
  resFilters = {}
  for dataset, filter1 of filters1
    filter2 = filters2[dataset]
    throw new Error("unmatched datasets") unless filter2
    resFilters[dataset] = new AndFilter([filter1, filter2]).simplify()
  return resFilters


# Make lookup
filterConstructorMap = {
  "true": TrueFilter
  "false": FalseFilter
  "is": IsFilter
  "in": InFilter
  "contains": ContainsFilter
  "match": MatchFilter
  "within": WithinFilter
  "not": NotFilter
  "and": AndFilter
  "or": OrFilter
}

FacetFilter.fromSpec = (filterSpec) ->
  throw new Error("unrecognizable filter") unless typeof filterSpec is 'object'
  throw new Error("type must be defined") unless filterSpec.hasOwnProperty('type')
  throw new Error("type must be a string") unless typeof filterSpec.type is 'string'
  FilterConstructor = filterConstructorMap[filterSpec.type]
  throw new Error("unsupported filter type '#{filterSpec.type}'") unless FilterConstructor
  return new FilterConstructor(filterSpec)


# Export!
exports.FacetFilter = FacetFilter
exports.TrueFilter = TrueFilter
exports.FalseFilter = FalseFilter
exports.IsFilter = IsFilter
exports.InFilter = InFilter
exports.ContainsFilter = ContainsFilter
exports.MatchFilter = MatchFilter
exports.WithinFilter = WithinFilter
exports.NotFilter = NotFilter
exports.AndFilter = AndFilter
exports.OrFilter = OrFilter
