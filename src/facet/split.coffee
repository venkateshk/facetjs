# A split is a function that takes a row and returns a string-able thing.

facet.split = {
  identity: (attribute) -> {
      bucket: 'identity'
      attribute
    }

  continuous: (attribute, size, offset) -> {
      bucket: 'continuous'
      attribute
      size
      offset
    }

  time: (attribute, duration) ->
    throw new Error("Invalid duration '#{duration}'") unless duration in ['second', 'minute', 'hour', 'day']
    return {
      bucket: 'time'
      attribute
      duration
    }
}