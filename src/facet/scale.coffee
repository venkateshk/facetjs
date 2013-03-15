# A function that makes a scale and adds it to the segment.
# Arguments* -> Segment -> { fn, use }

facet.scale = {
  linear: ({nice} = {}) -> (segments, {include, domain, range}) ->
    domain = wrapLiteral(domain)
    range = wrapLiteral(range)

    domainMin = Infinity
    domainMax = -Infinity
    rangeFrom = -Infinity
    rangeTo = Infinity

    if include?
      domainMin = Math.min(domainMin, include)
      domainMax = Math.max(domainMax, include)

    for segment in segments
      domainValue = domain(segment)
      if domainValue instanceof Interval
        domainMin = Math.min(domainMin, domainValue.start)
        domainMax = Math.max(domainMax, domainValue.end)
      else
        domainMin = Math.min(domainMin, domainValue)
        domainMax = Math.max(domainMax, domainValue)

      rangeValue = range(segment)
      if rangeValue instanceof Interval
        rangeFrom = rangeValue.start # really?
        rangeTo = Math.min(rangeTo, rangeValue.end)
      else
        rangeFrom = 0
        rangeTo = Math.min(rangeTo, rangeValue)

    if not (isFinite(domainMin) and isFinite(domainMax) and isFinite(rangeFrom) and isFinite(rangeTo))
      throw new Error("we went into infinites")

    basicScale = d3.scale.linear()
      .domain([domainMin, domainMax])
      .range([rangeFrom, rangeTo])

    if nice
      basicScale.nice()

    scaleFn = (x) ->
      if x instanceof Interval
        return new Interval(basicScale(x.start), basicScale(x.end))
      else
        return basicScale(x)

    return {
      fn: scaleFn
      use: domain
    }

  log: ({plusOne}) -> (segments, {domain, range, include}) ->
    domain = wrapLiteral(domain)
    range = wrapLiteral(range)

    domainMin = Infinity
    domainMax = -Infinity
    rangeFrom = -Infinity
    rangeTo = Infinity

    if include?
      domainMin = Math.min(domainMin, include)
      domainMax = Math.max(domainMax, include)

    for segment in segments
      domainValue = domain(segment)
      if domainValue instanceof Interval
        domainMin = Math.min(domainMin, domainValue.start)
        domainMax = Math.max(domainMax, domainValue.end)
      else
        domainMin = Math.min(domainMin, domainValue)
        domainMax = Math.max(domainMax, domainValue)

      rangeValue = range(segment)
      if rangeValue instanceof Interval
        rangeFrom = rangeValue.start # really?
        rangeTo = Math.min(rangeTo, rangeValue.end)
      else
        rangeFrom = 0
        rangeTo = Math.min(rangeTo, rangeValue)

    if not (isFinite(domainMin) and isFinite(domainMax) and isFinite(rangeFrom) and isFinite(rangeTo))
      throw new Error("we went into infinites")

    basicScale = d3.scale.log()
      .domain([domainMin, domainMax])
      .range([rangeFrom, rangeTo])

    scaleFn = (x) ->
      if x instanceof Interval
        return new Interval(basicScale(x.start), basicScale(x.end))
      else
        return x

    return {
      fn: scaleFn
      use: domain
    }

  color: () -> (segments, {domain}) ->
    domain = wrapLiteral(domain)

    return {
      fn: d3.scale.category10().domain(segments.map(domain))
      use: domain
    }
}