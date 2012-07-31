svl = {}

# Dimension = {row} -> String
# Metric = {row} -> Number
# [Metric] = {row} -> [Number]

sum = (values) ->
  s = 0
  s += v for v in values
  return s

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

acc = (column) ->
  throw "no such column" unless column?
  return column if typeof column is 'function'
  return (d) -> d[column]

cross_data_ctx = (data, scale, extra) ->
  newData = []
  for datum in data
    newData.push {
      d: datum
      s: scale
      e: extra
    }
  return newData

make_dimension = (column) ->
  if column is '$all'
    fn = (row) -> '$all'
  else if column
    fn = (row) -> row[column]
  else
    throw 'wtf mate'
  fn.type = 'dimension'
  fn.column = column
  return fn

is_dimension = (d) -> typeof d is 'function' and d.type is 'dimension' and d.column


make_metric = (column) ->
  if column is '$count'
    fn = (rows) -> rows.length
  else if column is '$ident'
    fn = (rows) -> rows
  else if column
    fn = (rows) -> sum(rows.map((d) -> d[column]))
  else
    throw 'wtf mate'
  fn.type = 'metric'
  fn.column = column
  return fn

is_metric = (m) -> typeof m is 'function' and m.type is 'metric' and m.column


sac = (rows, split, apply) ->
  throw "split mist be a dimension" unless is_dimension(split) or split.splice?
  throw "apply must be a metric or a list of metrics" unless is_metric(apply) or apply.splice?

  if not split.splice
    split = [split]

  if not apply.splice
    apply = [apply]

  buckets = {}

  for row in rows
    bucketNameParts = []
    dimensionValues = {}
    for dim in split
      v = dim(row)
      dimensionValues[dim.column] = v
      bucketNameParts.push(v)

    key = bucketNameParts.join(' | ')
    bucket = (buckets[key] or= { rows: [], dimensionValues })
    bucket.rows.push(row)

  out = []
  for key,bucket of buckets
    newRow = bucket.dimensionValues
    for metric in apply
      v = metric(bucket.rows)
      newRow[metric.column] = v
    out.push(newRow)

  return out


# ------------------------------------------

scales = {
  linear: (data, fn, flipRange = false) ->
    s = d3.scale.linear()
      .domain([d3.min(data, fn), d3.max(data, fn)])
      .range(if flipRange then [1,0] else [0,1])
    return s

  color: (data, fn) ->
    s = d3.scale.category10()
      .domain(data.map(fn))
    return s
}

svl.plot = ({selector, size, dataSource, plot}) ->
  svg = d3.select(selector)
    .append('svg')
    .attr('class', 'svl')
    .attr('width',  size.width)
    .attr('height', size.height)

  data = dataSource.data

  ###
  scale: {
    x: { type: 'linear', column: 'Time' }
    y: { type: 'linear', column: 'Walk' }
  }
  ###

  plots = {
    facet: (cont, dataCtx, {split, scale, plot}) ->
      fsplit = acc(split)
      scale or= {}

      labelWidth = 60

      dataFn = (d,i) ->
        { data, scaleFn, size } = dataCtx.call(this,d,i)
        scaleFn = copy(scaleFn)

        splitData = sac(data, make_dimension(split), make_metric('$ident'))

        buckets = sortedUniq(splitData.map(fsplit).sort())
        scaleFn.vertical = d3.scale.ordinal()
          .domain(buckets)
          .rangeBands([0, 1])

        if scale.x
          fx = acc(scale.x.column)
          scaleFn.x = scales.linear(data, fx)

        if scale.y
          fy = acc(scale.y.column)
          scaleFn.y = scales.linear(data, fy, true)

        if scale.color
          fcolor = acc(scale.color.column)
          scaleFn.color = scales.color(data, fcolor)

        return cross_data_ctx(splitData, scaleFn, { width: size.width, height: size.height, num: buckets.length, fsplit })

      cont.datum(dataFn)
      sel = cont.selectAll('g').data((d) -> d)
      enterSel = sel.enter().append('g')
      enterSel.append('text').attr('dy', '1em')
      enterSel.append('g')

      sel.exit().remove()
      sel
        .attr('transform', (d) -> s = d.s.vertical; "translate(0, #{s(d.e.fsplit(d.d)) * d.e.height})")

      sel.select('text')
        .text((d) -> fsplit(d.d))

      innerGroup = sel.select('g')
        .attr('transform', "translate(#{labelWidth}, 0)")

      if plot
        plot = [plot] unless plot.splice
        for p in plot
          doPlot(
            innerGroup
            (d) -> { data:d.d.$ident, scaleFn:d.s, size: { width: d.e.width-labelWidth, height: d.e.height/d.e.num }}
            p
          )

      return

    # ------------------------------------------------------------------------------------
    # rect: (cont, dataCtx, {x, y, plot}) ->
    #   fx = acc(x)
    #   fy = acc(y)

    #   dataFn = (d,i) ->
    #     { data, scale, size } = dataCtx.call(this,d,i)
    #     scale = copy(scale)
    #     scale.x = scales.linear(data, fx) if fx
    #     scale.y = scales.linear(data, fy, true) if fy
    #     return cross_data_ctx(data, scale, size)

    #   cont.datum(dataFn)
    #   sel = cont.selectAll('rect').data((d) -> [d])
    #   sel.enter().append('rect')
    #   sel.exit().remove()
    #   sel
    #     .attr('width',  (ds) -> d = ds[0]; d.e.width)
    #     .attr('height', (ds) -> d = ds[0]; d.e.height)
    #     .style('fill', '#efefef')

    #   # sel = cont.selectAll('line').data((d) -> d)
    #   # sel.enter().append('line')
    #   # sel.exit().remove()
    #   # sel
    #   #   .attr('width',  (ds) -> d = ds[0]; d.e.width)
    #   #   .attr('height', (ds) -> d = ds[0]; d.e.height)
    #   #   .style('fill', '#efefef')

    #   # sel.style('fill', (d) -> s = d.s.color; if s then s(s.by(d.d)) else null)

    #   throw "can not subplot" if plot
    #   return

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

    # # ------------------------------------------------------------------------------------
    # line: (cont, dataCtx, {x, y, color, plot}) ->
    #   fx = acc(x)
    #   fy = acc(y)
    #   fcolor = acc(color)

    #   dataFn = (d,i) ->
    #     { data, scale, size } = dataCtx.call(this,d,i)

    #     scale = copy(scale)
    #     scale.x = scales.linear(data, fx) if fx
    #     scale.y = scales.linear(data, fy, true) if fy
    #     scale.color = scales.color(data, fcolor) if fcolor
    #     return cross_data_ctx(data, scale, size)

    #   cont.datum(dataFn)
    #   sel = cont.selectAll('path').data((d) -> [d])
    #   sel.enter().append('path')
    #   sel.exit().remove()
    #   sel
    #     .attr('d', d3.svg.line().x((d) -> s = d.s.x; s(s.by(d.d)) * d.e.width).y((d) -> s = d.s.y; s(s.by(d.d)) * d.e.height))

    #   sel
    #     .style('fill', 'none')
    #     .style('stroke', (ds) -> d = ds[0]; s = d.s.color; if s then s(s.by(d.d)) else null)

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
    -> {data, scale:{}, size}
    plot
  )
  return

# ------------------------------------------

data = do ->
  pick = (arr) -> arr[Math.floor(Math.random() * arr.length)]

  now = Date.now()
  w = 100
  return d3.range(400).map (i) ->
    return {
      id: i
      Time: new Date(now + i * 13 * 1000)
      Letter: 'ABC'[Math.floor(3 * i/400)]
      Number: pick('1234')
      ScoreA: i * Math.random() * Math.random()
      ScoreB: 10 * Math.random()
      Walk: w += Math.random() - 0.5 + 0.02
    }

# d3.select('.cont').append('div').text('just point')

# svl.plot {
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

svl.plot {
  selector: '.cont'
  size:
    width: 600
    height: 600
  dataSource:
    data: data
    removeNA: false
  plot:
    type: 'facet'
    split: 'Letter'
    scale:
      x: { type: 'linear', column: 'Time' }
    plot:
      type: 'points'
      mapping:
        x: 'Time'
        y: 'Walk'
        color: 'Letter'
      scale:
        y: { type: 'linear', column: 'Walk' }
        color: { type: 'color', column: 'Letter' }
}




