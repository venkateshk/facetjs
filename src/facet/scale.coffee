# A function that makes a scale and adds it to the segment.
# Arguments* -> Segment -> void

facet.scale = {
  linear: ({nice} = {}) -> (segments, {include, domain, range}) ->
    domain = wrapLiteral(domain)

    if range in ['width', 'height']
      rangeFn = (segment) -> [0, segment.getStage()[range]]
    else if typeof range is 'number'
      rangeFn = -> [0, range]
    else if Array.isArray(range) and range.length is 2
      rangeFn = -> range
    else
      throw new Error("bad range")

    domainMin = Infinity
    domainMax = -Infinity
    rangeFrom = -Infinity
    rangeTo = Infinity

    if include?
      domainMin = Math.min(domainMin, include)
      domainMax = Math.max(domainMax, include)

    for segment in segments
      domainValue = domain(segment)
      domainMin = Math.min(domainMin, domainValue)
      domainMax = Math.max(domainMax, domainValue)

      rangeValue = rangeFn(segment)
      rangeFrom = rangeValue[0]
      rangeTo = Math.min(rangeTo, rangeValue[1])

    if not (isFinite(domainMin) and isFinite(domainMax) and isFinite(rangeFrom) and isFinite(rangeTo))
      throw new Error("we went into infinites")

    scaleFn = d3.scale.linear()
      .domain([domainMin, domainMax])
      .range([rangeFrom, rangeTo])

    if nice
      scaleFn.nice()

    return {
      fn: scaleFn
      use: domain
    }

  log: ({plusOne}) -> (segments, {domain, range, include}) ->
    domain = wrapLiteral(domain)

    if range in ['width', 'height']
      rangeFn = (segment) -> [0, segment.getStage()[range]]
    else if typeof range is 'number'
      rangeFn = -> [0, range]
    else if Array.isArray(range) and range.length is 2
      rangeFn = -> range
    else
      throw new Error("bad range")

    domainMin = Infinity
    domainMax = -Infinity
    rangeFrom = -Infinity
    rangeTo = Infinity

    if include?
      domainMin = Math.min(domainMin, include)
      domainMax = Math.max(domainMax, include)

    for segment in segments
      domainValue = domain(segment)
      domainMin = Math.min(domainMin, domainValue)
      domainMax = Math.max(domainMax, domainValue)

      rangeValue = rangeFn(segment)
      rangeFrom = rangeValue[0]
      rangeTo = Math.min(rangeTo, rangeValue[1])

    if not (isFinite(domainMin) and isFinite(domainMax) and isFinite(rangeFrom) and isFinite(rangeTo))
      throw new Error("we went into infinites")

    return {
      fn: d3.scale.log().domain([domainMin, domainMax]).range([rangeFrom, rangeTo])
      use: domain
    }

  color: () -> (segments, {domain}) ->
    domain = wrapLiteral(domain)

    return {
      fn: d3.scale.category10().domain(segments.map(domain))
      use: domain
    }
}