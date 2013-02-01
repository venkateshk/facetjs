facet = {}

# Dimension = {row} -> String
# Metric = {row} -> Number
# [Metric] = {row} -> [Number]

sortedUniq = (arr) ->
  u = []
  last = u
  for a in arr
    u.push(a) if a isnt last
    last = a
  return u

copy = (obj) ->
  newObj = {}
  for k,v of obj
    newObj[k] = v
  return newObj

makeArray = (obj) ->
  if obj? then (if obj.splice then obj else [obj]) else []

acc = (column) ->
  throw "no such column" unless column?
  return column if typeof column is 'function'
  return (d) -> d[column]

cross = (arrays) ->
  vectorName = []
  vectorValues = []
  retLength = 1
  for k,vs of arrays
    return [] unless vs.splice
    vectorName.push(k)
    vectorValues.push(vs)
    retLength *= vs.length

  return [] unless vectorValues.length

  ret = []
  i = 0
  while i < retLength
    row = {}
    k = i
    for vs,j in vectorValues
      t = k % vs.length
      row[vectorName[j]] = vs[t]
      k = Math.floor(k / vs.length)

    ret[i] = row
    i++

  return ret


window.tile = {
  vertical: (rect, datas) ->
    total = 0
    for d in datas
      total += d

    scale = rect.height / total
    rects = []
    y = 0
    for d in datas
      h = d * scale
      rects.push {
        x: 0
        y: y
        width: rect.width
        height: h
      }
      y += h

    return rects
}

# ------------------------------------------------------------------

# Valid:
# {name, column} = {name}
# {name, type: all }
facet.dimension = do ->
  binMap = {
    millisecond: 1
    second: 1000
    minute: 60 * 1000
    hour: 60 * 60 * 1000
    day: 24 * 60 * 60 * 1000
    week: 7 * 24 * 60 * 60 * 1000
  }
  return (name, {column, type, bin}) ->
    throw "name can not start with $  (#{name})" if name[0] is '$'
    column = name.toLowerCase() unless column
    switch type
      when 'all'
        fn = (row) -> '$all'
      when 'categorical'
        throw 'categorical dimension must have column' unless column
        fn = (row) -> row[column]
      when 'ordinal'
        throw 'ordinal dimension must have column' unless column
        fn = (row) -> row[column]
      when 'continuous'
        throw 'continuous dimension must have column' unless column
        throw 'continuous dimension must have bin' unless bin
        bin = binMap[bin] if binMap[bin]
        fn = (row) -> Math.floor(row[column] / bin)
      else
        throw 'must have a type'
    fn.$name = name
    return fn

# Valid:
# {column}
# {agg: 'count' }
facet.metric = do ->
  aggregartion = {
    sum: (values) ->
      sum = 0
      for v in values
        sum += v
      return sum

    average: (values) ->
      sum = 0
      for v in values
        sum += v
      return sum / values.length

    uniq: (values) ->
      seen = {}
      count = 0
      for v in values
        continue if seen[v]
        count++
        seen[v] = 1
      return count

    common: (values) ->
      counts = {}
      # to do
      return values[0]
  }
  return (name, {column, agg}) ->
    throw "name can not start with $  (#{name})" if name[0] is '$'
    column = name.toLowerCase() unless column
    if agg is 'const'
      fn = (rows) -> 1
    else if agg is 'count'
      fn = (rows) -> rows.length
    else if column
      a = aggregartion[agg]
      throw "invalid agg (#{agg})" unless a
      fn = (rows) -> a(rows.map((d) -> d[column]))
    else
      throw "needs agg == 'count' or column"
    fn.$name = name
    return fn


# combine =
#  sort: <dimension or metric name>
#  order: asc | desc
#  skip: <number>
#  limit: <number>
facet.data = (rows) ->
  splits = []
  dimensions = {}
  metrics = {}

  makeSac = ({split, apply, combine}, breakdown) -> (rows) ->
    buckets = {}

    for row in rows
      bucketNameParts = []
      dimensionValues = {}
      for dim in split
        v = dim(row)
        dimensionValues[dim.$name] = v
        bucketNameParts.push(v)

      key = bucketNameParts.join(' | ')
      bucket = (buckets[key] or= { rows: [], dimensionValues })
      bucket.rows.push(row)

    out = []
    for key,bucket of buckets
      newRow = bucket.dimensionValues

      if breakdown
        newRow['$split'] = bucket.rows

      for metric in apply
        v = metric(bucket.rows)
        newRow[metric.$name] = v

      out.push(newRow)

    if combine
      { sort, order, skip, limit } = combine
      if sort
        cmpFn = if order is 'asc' then d3.ascending else d3.descending
        out.sort (a,b) -> cmpFn(a[sort], b[sort])

      if skip? or limit?
        skip or= 0
        out = if limit? then out.slice(skip, skip+limit) else out.slice(skip)

    return out

  query = ({dimensions, metrics, splits}) ->
    for name, spec of dimensions
      spec = facet.dimension(name, spec) unless typeof spec is 'function'
      dimensions[name] = spec

    for name, spec of metrics
      spec = facet.metric(name, spec) unless typeof spec is 'function'
      metrics[name] = spec

    splits = splits.map ({split, apply, combine}) ->
      split = makeArray(split).map (d) ->
        if typeof d is 'string'
          dim = dimensions[d]
          throw "Unknown dimension '#{d}'" unless dim
          return dim
        else
          return d

      apply = makeArray(apply).map (m) ->
        if typeof m is 'string'
          met = metrics[m]
          throw "Unknown metric '#{m}'" unless met
          return met
        else
          return m

      if combine and combine.sort
        throw 'combine.sort must be a dimension or a metric' unless dimensions[combine.sort] or metrics[combine.sort]

      return { split, apply, combine }

    numSplits = splits.length
    throw 'no splits defined' unless splits

    dummy = {}
    dummy['$split'] = rows

    stage = [dummy]
    for s,i in splits
      sacFn = makeSac(s, i < numSplits-1)
      newStages = []
      for st in stage
        mappedRows = sacFn(st['$split'])
        st['$split'] = mappedRows
        newStages.push(mappedRows)

      stage = Array::concat.apply([], newStages)

    return dummy['$split']

  return { query }


# ------------------------------------------

facet.scale = do ->
  scales = {
    linear: ({from}, data, flipRange = false) ->
      fn = (d) -> d[from]
      s = d3.scale.linear()
        .domain(d3.extent(data, fn))
        .range(if flipRange then [1,0] else [0,1])
      return s

    color: ({from}, data) ->
      fn = (d) -> d[from]
      s = d3.scale.category10()
        .domain(data.map(fn))
      return s
  }

  return (scaleSpec, data, flipRange) ->
    throw 'scale spec must have type' unless scaleSpec.type
    s = scales[scaleSpec.type]
    throw "no such scale type (#{scaleSpec.type})" unless s
    return s(scaleSpec, data, flipRange)


facet.plot = ({selector, size, data, plot}) ->
  svg = d3.select(selector)
    .append('svg')
    .attr('class', 'facet')
    .attr('width',  size.width)
    .attr('height', size.height)

  {sac, dimensions, metrics} = data

  ###
  scale: {
    x: { type: 'linear', column: 'Time' }
    y: { type: 'linear', column: 'Walk' }
  }
  ###

  plots = {
    facet: (cont, dataCtx, {split, scale, mapping, plot}) ->
      fsplit = acc(split)
      scale or= {}

      dataFn = (d,i) ->
        { data, scaleFn, size } = dataCtx.call(this,d,i)
        scaleFn = copy(scaleFn)

        buckets = data.map (d) -> d.$split[split]

        if scale.x
          scaleFn.x = facet.scale(scale.x, data)

        if scale.y
          scaleFn.y = facet.scale(scale.y, data, true)

        if scale.color
          scaleFn.color = facet.scale(scale.color, data)

        return cross {
          d: data.$split
          s: [scaleFn]
          e: [{ width: size.width, height: size.height, num: buckets.length, fsplit }]
        }

      cont.datum(dataFn)
      sel = cont.selectAll('g').data((d) -> d)
      sel.enter().append('g')

      sel.exit().remove()
      sel
        .attr('transform', (d) -> s = d.s.vertical; "translate(0, #{s(d.e.fsplit(d.d)) * d.e.height})")

      if plot
        plot = [plot] unless plot.splice
        for p in plot
          doPlot(
            sel
            (d) -> { data:d.d.$ident, scaleFn:d.s, size: { width: d.e.width, height: d.e.height/d.e.num }}
            p
          )

      return

    # ------------------------------------------------------------------------------------
    points: (cont, dataCtx, {mapping, scale, plot}) ->
      dataFn = (d,i) ->
        { data, scaleFn, size } = dataCtx.call(this,d,i)
        scaleFn = copy(scaleFn)

        if scale.x
          fx = acc(scale.x.column)
          scaleFn.x = scales.linear(data, fx)

        if scale.y
          fy = acc(scale.y.column)
          scaleFn.y = scales.linear(data, fy, true)

        if scale.color
          fcolor = acc(scale.color.column)
          scaleFn.color = scales.color(data, fcolor)

        mappingFn = {}
        for k,m of mapping
          mappingFn[k] = acc(m)

        return cross_data_ctx(data, scaleFn, { width: size.width, height: size.height, m:mappingFn })

      cont.datum(dataFn)
      sel = cont.selectAll('circle').data((d) -> d)
      sel.enter().append('circle')
      sel.exit().remove()
      sel
        .attr('cx', (d) -> d.s.x(d.e.m.x(d.d)) * d.e.width)
        .attr('cy', (d) -> d.s.y(d.e.m.y(d.d)) * d.e.height)
        .attr('r', 3.5)
        .style('fill', (d) -> s = d.s.color; if s then s(d.e.m.color(d.d)) else null)

      throw "can not subplot" if plot
      return

    # # ------------------------------------------------------------------------------------
    # text: (cont, dataCtx, {split, apply, x, y, text, color, plot}) ->
    #   fx = acc(x)
    #   fy = acc(y)
    #   fcolor = acc(color)
    #   ftext = acc(text)

    #   dataFn = (d,i) ->
    #     { data, scale, size } = dataCtx.call(this,d,i)

    #     splitData = sac(data, make_dimension(split or '$all'), make_metric(apply))

    #     scale = copy(scale)
    #     scale.x = scales.linear(data, fx) if fx
    #     scale.y = scales.linear(data, fy, true) if fy
    #     scale.color = scales.color(data, fcolor) if fcolor
    #     return cross_data_ctx(splitData, scale, size)

    #   cont.datum(dataFn)
    #   sel = cont.selectAll('text').data((d) -> d)
    #   sel.enter().append('text')
    #   sel.exit().remove()
    #   sel
    #     .attr('x', 0) #(d) -> s = d.s.x; s(s.by(d.d)) * d.e.width)
    #     .attr('y', 0) #(d) -> s = d.s.y; s(s.by(d.d)) * d.e.height)
    #     .attr('dy', '1em')
    #     .text((d) -> ftext(d.d))

    #   throw "can not subplot" if plot
    #   return
  }

  doPlot = (parent, dataCtx, args) ->
    throw "type must be a string" unless typeof args.type is 'string'
    p = plots[args.type]
    throw "unknown type '#{args.type}'" unless p
    p(parent.append('g').attr('class', args.type), dataCtx, args)
    return

  doPlot(
    svg
    -> {data:sac, scale:{}, size}
    plot
  )
  return

facet.makeData = ({selector, size, dataSpec, plot}) ->
  { from, dimensions, metrics } = dataSpec

  splits = []
  split = [{ apply, combine: null }]
  while plot
    split.push(plot.split)
    apply = []
    for k,m of plot.mapping
      apply.push(m) unless m in split
    splits.push { split: split.slice(), apply, combine: null }
    plot = plot.plot

  dataSac = facet.data(from).query {
    dimensions
    metrics
    splits
  }

  return {
    selector
    size
    data: {
      sac: dataSac
      dimensions
      metrics
    }
    plot
  }

# ------------------------------------------

data = do ->
  pick = (arr) -> arr[Math.floor(Math.random() * arr.length)]

  now = Date.now()
  w = 100
  return d3.range(400).map (i) ->
    return {
      id: i
      time: new Date(now + i * 13 * 1000)
      letter: 'ABC'[Math.floor(3 * i/400)]
      number: pick(['1', '10', '3', '4'])
      scoreA: i * Math.random() * Math.random()
      scoreB: 10 * Math.random()
      walk: w += Math.random() - 0.5 + 0.02
    }

# d3.select('.cont').append('div').text('just point')

# facet.plot {
#   selector: '.cont'
#   size:
#     width: 600
#     height: 600
#   dataSource:
#     data: data
#     removeNA: false
#   plot:
#     type: 'points'
#     y: 'Walk'
# }

spec = {
  selector: '.cont'
  size:
    width:  800
    height: 600
  dataSpec:
    from: data
    dimensions:
      Time:   { type: 'continuous', bin: 'second' }
      Letter: { type: 'categorical' }
      Number: { type: 'ordinal' }
    metrics:
      Const:  { agg: 'const' }
      Count:  { agg: 'count' }
      Walk:   { agg: 'average' }
  plot:
    type: 'facet'
    method: 'vertical'
    mapping: { area: 'Const' }
    split: 'Letter'
    scale:
      x: { type: 'linear', from: 'Time' }
    # plot:
    #   split: 'Time'
    #   type: 'point'
    #   mapping:
    #     x: 'Time'
    #     y: 'Walk'
    #     color: 'Letter'
    #   scale:
    #     y: { type: 'linear', from: 'Walk' }
    #     color: { type: 'color', from: 'Letter' }
}

#facet.plot spec
console.log '-----------'
console.log facet.makeData(spec)
console.log '-----------'

testCarData = [
  { make: 'Honda',  model: 'Civic',   price: 10000 }
  { make: 'Honda',  model: 'Civic',   price: 10100 }
  { make: 'Honda',  model: 'Element', price: 13000 }
  { make: 'Toyota', model: 'Corrola', price: 11000 }
  { make: 'Toyota', model: 'Corrola', price: 11100 }
  { make: 'BMW',    model: 'M3',      price: 51000 }
  { make: 'BMW',    model: 'M5',      price: 61000 }
]

console.log facet.data(testCarData).query {
  dimensions:
    'Make': { type: 'categorical' }
    'Model': { type: 'categorical' }
  metrics:
    'Total Price': { agg: 'sum', column: 'price' }
    'Avg Price': { agg: 'average', column: 'price' }
    'Count': { agg: 'count' }
  splits: [
    { split: 'Make',  apply: ['Count', 'Total Price', 'Avg Price'] }
    { split: 'Model', apply: ['Count', 'Total Price', 'Avg Price'] }
  ]
}

# what is the most common model of car for each manufacturer
# carSales.split('Mfr', [], 'alphbetic').split('Model', 'count', 'sort desc limit 1')
# carSales.split('Mfr', Model_most_popular, 'alphbetic')

