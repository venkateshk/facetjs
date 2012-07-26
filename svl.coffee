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
  return null unless column?
  return column if typeof column is 'function'
  return (d) -> d[column]

cross_data_scales = (data, scales) ->
  newData = []
  for datum in data
    newData.push {
      d: datum
      s: scales
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

svl.plot = ({selector, size, dataSource, plot}) ->
  svg = d3.select(selector)
    .append('svg')
    .attr('class', 'svl')
    .attr('width', size.width)
    .attr('height', size.height)

  data = dataSource.data

  plots = {
    facet: (parent, size, data, {split, plot, x, y, color}) ->
      fsplit = acc(split)
      fx = acc(x)
      fy = acc(y)
      fcolor = acc(color)

      sel = parent.selectAll('g')
        .data((d,i) ->
            if typeof data is 'function'
              { data: myData, scales } = data.call(this,d,i)
            else
              myData = data
              scales = {}

            splitData = sac(myData, make_dimension(split), make_metric('$ident'))

            scale = copy(scales)

            buckets = sortedUniq(splitData.map(fsplit).sort())
            scale.vertical = d3.scale.ordinal()
              .domain(buckets)
              .rangeBands([0, 1])
            scale.vertical.by = fsplit

            if fx
              scale.x = d3.scale.linear()
                .domain([d3.min(myData, fx), d3.max(myData, fx)])
                .range([0, 1])
              scale.x.by = fx

            if fy
              scale.y = d3.scale.linear()
                .domain([d3.min(myData, fy), d3.max(myData, fy)])
                .range([1, 0])
              scale.y.by = fy

            if fcolor
              scale.color = d3.scale.category10()
                .domain(myData.map(fcolor))
              scale.color.by = fcolor

            return cross_data_scales(splitData, scale)
          )


      enterSel = sel.enter().append('g')
      enterSel.append('text').attr('dy', '1em')
      enterSel.append('g')

      sel.exit().remove()
      sel
        .attr('transform', (d) -> s = d.s.vertical; "translate(0, #{s(s.by(d.d)) * size.height})")

      sel.select('text')
        .text((d) -> fsplit(d.d))

      labelWidth = 60
      innerGroup = sel.select('g')
        .attr('transform', "translate(#{labelWidth}, 0)")

      if plot
        doPlot(
          innerGroup
          {width: size.width-labelWidth, height: size.height/4}
          (d) -> { data:d.d.$ident, scales:d.s }
          plot
        )
      return

    points: (parent, size, data, {x, y, color}) ->
      fx = acc(x)
      fy = acc(y)
      fcolor = acc(color)

      sel = parent.selectAll('circle')
        .data((d,i) ->
            if typeof data is 'function'
              { data: myData, scales } = data.call(this,d,i)
            else
              myData = data
              scales = {}

            scale = copy(scales)

            if fx
              scale.x = d3.scale.linear()
                .domain([d3.min(myData, fx), d3.max(myData, fx)])
                .range([0, 1])
              scale.x.by = fx

            if fy
              scale.y = d3.scale.linear()
                .domain([d3.min(myData, fy), d3.max(myData, fy)])
                .range([1, 0])
              scale.y.by = fy

            if fcolor
              scale.color = d3.scale.category10()
                .domain(myData.map(fcolor))
              scale.color.by = fcolor

            return cross_data_scales(myData, scale)
          )

      sel.enter().append('circle')
      sel.exit().remove()
      sel
        .attr('cx', (d) -> s = d.s.x; s(s.by(d.d)) * size.width)
        .attr('cy', (d) -> s = d.s.y; s(s.by(d.d)) * size.height)
        .attr('r', 3.5)

      sel.style('fill', (d) -> s = d.s.color; if s then s(s.by(d.d)) else null)

      return

    text: (parent, size, data, {text}) ->

      return
  }

  doPlot = (parent, size, data, args) ->
    throw "type must be a string" unless typeof args.type is 'string'
    p = plots[args.type]
    throw "unknown type '#{args.type}'" unless p
    p(parent.append('g').attr('class', args.type), size, data, args)
    return

  doPlot(svg, size, data, plot)

  return

# ------------------------------------------

data = do ->
  pick = (arr) -> arr[Math.floor(Math.random() * arr.length)]

  now = Date.now()
  return d3.range(400).map (i) ->
    return {
      id: i
      Time: new Date(now + i * 13 * 1000)
      Letter: 'ABC'[Math.floor(3 * i/400)]
      Number: pick('1234')
      ScoreA: i * Math.random() * Math.random()
      ScoreB: 10 * Math.random()
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
#     x: 'Time'
#     y: 'ScoreA'
#     color: 'Letter'
# }

# d3.select('.cont').append('div').text('just facet Number > point')

# svl.plot {
#   selector: '.cont'
#   size:
#     width: 600
#     height: 600
#   dataSource:
#     data: data
#     removeNA: false
#   plot:
#     type: 'facet'
#     split: 'Number'
#     plot:
#       type: 'points'
#       x: 'Time'
#       y: 'ScoreA'
#       color: 'Letter'
# }

d3.select('.cont').append('div').text('just facet Letter > point')

# svl.plot {
#   selector: '.cont'
#   size:
#     width: 600
#     height: 600
#   dataSource:
#     data: data
#     removeNA: false
#   plot:
#     type: 'facet'
#     split: 'Letter'
#     x: 'Time'
#     y: 'ScoreA'
#     plot:
#       type: 'points'
#       color: 'Letter'
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
    split: 'Number'
    plot:
      type: 'facet'
      split: 'Letter'
      x: 'Time'
      color: 'Letter'
      plot:
        type: 'points'
        y: 'ScoreA'
}

# Split by 'Number' [facet options: {direction: vertical}]
# Split by 'Time' don't bucket [measure ScoreA]
# plot points
# plot line

















