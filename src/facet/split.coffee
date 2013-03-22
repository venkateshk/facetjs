# A split is a function that takes a row and returns a string-able thing.

facet.split = {
  identity: (attribute) -> {
      bucket: 'identity'
      attribute
    }

  continuous: (attribute, size, offset) ->
    throw new Error("continuous split must have #{size}") unless size
    offset ?= 0
    return {
      bucket: 'continuous'
      attribute
      size
      offset
    }

  time: (attribute, duration, timezone) ->
    throw new Error("Invalid duration '#{duration}'") unless duration in ['second', 'minute', 'hour', 'day']
    return {
      bucket: 'time'
      attribute
      duration
      timezone
    }
}