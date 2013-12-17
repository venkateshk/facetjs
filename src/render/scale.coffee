d3 = require('d3')
{wrapLiteral} = require('./common')
Interval = require('./interval')

# A function that makes a scale and adds it to the segment.
# Arguments* ->
#  domain: [Segment], use
#  range: [Space], use
#    -> { fn, use }

scaleOverInterval = (baseScale) -> (x) ->
  if x instanceof Interval
    return new Interval(baseScale(x.start), baseScale(x.end))
  else
    return baseScale(x)

min = (a, b) -> if a < b then a else b
max = (a, b) -> if a < b then b else a

module.exports = {
  linear: ({nice, time} = {}) -> return ->
    baseScale = if time then d3.time.scale() else d3.scale.linear()

    self = {
      domain: (segments, domain) ->
        domain = wrapLiteral(domain)

        domainMin = Infinity
        domainMax = -Infinity

        for segment in segments
          domainValue = domain(segment)
          if domainValue instanceof Interval
            domainMin = min(domainMin, min(domainValue.start, domainValue.end))
            domainMax = max(domainMax, max(domainValue.start, domainValue.end))
          else
            domainMin = min(domainMin, domainValue)
            domainMax = max(domainMax, domainValue)

        throw new Error("Domain went into infinites") unless isFinite(domainMin) and isFinite(domainMax)
        baseScale.domain([domainMin, domainMax])

        if nice
          baseScale.nice()

        delete self.domain
        self.base = baseScale
        self.use = domain
        self.fn = scaleOverInterval(baseScale)
        return

      range: (spaces, range) ->
        range = wrapLiteral(range)

        rangeFrom = -Infinity
        rangeTo = Infinity

        for space in spaces
          rangeValue = range(space)
          if rangeValue instanceof Interval
            rangeFrom = rangeValue.start # really?
            rangeTo = min(rangeTo, rangeValue.end)
          else
            rangeFrom = 0
            rangeTo = min(rangeTo, rangeValue)

        throw new Error("Range went into infinites") unless isFinite(rangeFrom) and isFinite(rangeTo)
        baseScale.range([rangeFrom, rangeTo])
        delete self.range
        return
    }

    return self


  color: ({colors} = {}) -> return ->
    baseScale = d3.scale.category10()

    self = {
      domain: (segments, domain) ->
        domain = wrapLiteral(domain)

        baseScale = baseScale.domain(segments.map(domain))

        delete self.domain
        self.use = domain
        self.fn = scaleOverInterval(baseScale)
        return

      range: (segments, range) ->
        delete self.range
        return
    }

    return self
}
