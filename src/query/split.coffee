
class FacetSplit
  constructor: ->
    return

  _ensureBucket: (bucket) ->
    if not @bucket
      @bucket = bucket # Set the bucket if it is so far undefined
      return
    if @bucket isnt bucket
      throw new TypeError("incorrect split bucket '#{@bucket}' (needs to be: '#{bucket}')")
    return

  _addName: (str) ->
    return str unless @name
    return "#{@name} <- #{str}"

  toString: ->
    return @_addName("base split")

  valueOf: ->
    throw new Error("base split has no value")



class IdentitySplit extends FacetSplit
  constructor: ({name, @bucket, @attribute, options}) ->
    @name = name if name
    @options = new FacetOptions(options) if option
    @_ensureBucket('identity')

  toString: ->
    return @_addName(String(@value))

  valueOf: ->
    split = { aggregate: @aggregate }
    split.name = @name if @name
    return split



class ContinuousSplit extends FacetSplit
  constructor: ({name, @bucket, @attribute, options}) ->
    @name = name if name
    @options = new FacetOptions(options) if option
    @_ensureBucket('continuous')



class TimeDurationSplit extends FacetSplit
  constructor: ({name, @bucket, @attribute, options}) ->
    @name = name if name
    @options = new FacetOptions(options) if option
    @_ensureBucket('timeDuration')



class TimePeriodSplit extends FacetSplit
  constructor: ({name, @bucket, @attribute, options}) ->
    @name = name if name
    @options = new FacetOptions(options) if option
    @_ensureBucket('timePeriod')



class TupleSplit extends FacetSplit
  constructor: ({name, @bucket, @attribute, options}) ->
    @name = name if name
    @options = new FacetOptions(options) if option
    @_ensureBucket('tuple')




















