
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
  constructor: ->
    switch args.length
      when 1
        if typeof args[0] isnt 'string'
          { @name, @bucket, @attribute } = args[0]
        else
          [@attribute] = args

      when 2
        if typeof args[1] is 'string'
          [@name, @attribute] = args
        else
          [@attribute, @options] = args

      when 3
        [@name, @attribute, @options] = args

      else
        throwBadArgs()
    @_ensureBucket('identity')

  toString: ->
    return @_addName(String(@value))

  valueOf: ->
    split = { aggregate: @aggregate }
    split.name = @name if @name
    return split



class ContinuousSplit extends FacetSplit
  constructor: ->
    @_ensureBucket('continuous')



class TimeDurationSplit extends FacetSplit
  constructor: ->
    @_ensureBucket('timeDuration')



class TimePeriodSplit extends FacetSplit
  constructor: ->
    @_ensureBucket('timePeriod')



class TupleSplit extends FacetSplit
  constructor: ->
    @_ensureBucket('tuple')




















