# A function that makes a scale and adds it to the segment.
# Arguments* -> Segment -> { fn, use }

scaleOverInterval = (basicScale) -> (x) ->
  if x instanceof Interval
    return new Interval(basicScale(x.start), basicScale(x.end))
  else
    return basicScale(x)


facet.scale = {
  linear: ({nice} = {}) -> () ->
    basicScale = d3.scale.linear()

    self = {
      domain: (segments, domain) ->
        domain = wrapLiteral(domain)

        domainMin = Infinity
        domainMax = -Infinity

        for segment in segments
          domainValue = domain(segment)
          if domainValue instanceof Interval
            domainMin = Math.min(domainMin, domainValue.start)
            domainMax = Math.max(domainMax, domainValue.end)
          else
            domainMin = Math.min(domainMin, domainValue)
            domainMax = Math.max(domainMax, domainValue)

        throw new Error("Domain went into infinites") unless isFinite(domainMin) and isFinite(domainMax)
        basicScale.domain([domainMin, domainMax])

        if nice
          basicScale.nice()

        delete self.domain
        self.use = domain
        self.fn = scaleOverInterval(basicScale)
        return

      range: (segments, range) ->
        range = wrapLiteral(range)

        rangeFrom = -Infinity
        rangeTo = Infinity

        for segment in segments
          rangeValue = range(segment)
          if rangeValue instanceof Interval
            rangeFrom = rangeValue.start # really?
            rangeTo = Math.min(rangeTo, rangeValue.end)
          else
            rangeFrom = 0
            rangeTo = Math.min(rangeTo, rangeValue)

        throw new Error("Range went into infinites") unless isFinite(rangeFrom) and isFinite(rangeTo)

        basicScale.range([rangeFrom, rangeTo])
        delete self.range
        return
    }

    return self


  color: () -> () ->
    basicScale = d3.scale.category10()

    self = {
      domain: (segments, domain) ->
        domain = wrapLiteral(domain)

        basicScale = basicScale.domain(segments.map(domain))

        delete self.domain
        self.use = domain
        self.fn = scaleOverInterval(basicScale)
        return

      range: (segments, range) ->
        delete self.range
        return
    }

    return self
}
