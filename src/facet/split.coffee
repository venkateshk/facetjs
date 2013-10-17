# A split is a function that takes a row and returns a string-able thing.

facet.split = {
  identity: (attribute) ->
    return {
      bucket: 'identity'
      attribute
    }

  continuous: (attribute, size, offset = 0) ->
    throw new Error("continuous split must have #{size}") unless size
    return {
      bucket: 'continuous'
      attribute
      size
      offset
    }

  timeDuration: (attribute, duration, offset = 0) ->
    throw new Error("invalid duration '#{duration}'") if isNaN(duration)
    return {
      bucket: 'timeDuration'
      attribute
      duration
      offset
    }

  timePeriod: (attribute, period, timezone) ->
    throw new Error("invalid period '#{period}'") unless period in ['PT1S', 'PT1M', 'PT1H', 'P1D']
    return {
      bucket: 'timePeriod'
      attribute
      period
      timezone
    }

  tuple: (splits...) ->
    throw new Error("can not have an empty tuple") unless splits.length
    return {
      bucket: 'tuple'
      splits
    }
}
