# cols = ['year','name','percent','sex']


# d3.csv "bnames.csv", (data) ->
#   # var data = d3.nest()
#   #   .key(function(d) { return d.Date; })
#   #   .rollup(function(d) { return (d[0].Close - d[0].Open) / d[0].Open; })
#   #   .map(csv);

#   # rect.filter(function(d) { return d in data; })
#   #     .attr("class", function(d) { return "day q" + color(data[d]) + "-9"; })
#   #   .select("title")
#   #     .text(function(d) { return d + ": " + percent(data[d]); });

#   # name: "John"
#   # percent: "0.081541"
#   # sex: "boy"
#   # year: "1880"

#   # console.log(data)

#   data.forEach (d) ->
#     d.year = parseInt(d.year, 10)
#     d.percent = parseFloat(d.percent)
#     return

#   # data = data.filter((d) -> d.name[0] is 'A')

#   # make_table(data, (d) -> d.year + '_' + d.name)

#   # for each name find out the average year
#   fn = dw.sac(
#     dw.dimension.categorical('name')
#     dw.metric.average('year')
#     dw.sort('year', 'desc', 10)
#   )

#   console.log('output:', fn(data))

#   return

# colors = d3.range(20).map(d3.scale.category20().domain([0,19]))
# window.pivot = (col) ->
#   return unless col in cols

#   return




# sum = (array, column) ->
#   s = 0
#   for a in array
#     a = a[column]
#     s += a if !isNaN(a)
#   return s



# dw = { version: '0.0.1' }

# # return Row -> String
# dw.dimension = {
#   time: (column, alias) ->
#     fn = (row) -> row[column]
#     fn.alias = alias or column
#     fn.type = 'time'
#     return fn

#   interval: (column, alias) ->
#     fn = (row) -> row[column]
#     fn.alias = alias or column
#     fn.type = 'interval'
#     return fn

#   ordinal: (column, alias) ->
#     fn = (row) -> row[column]
#     fn.alias = alias or column
#     fn.type = 'ordinal'
#     return fn

#   categorical: (column, alias) ->
#     fn = (row) -> row[column]
#     fn.alias = alias or column
#     fn.type = 'categorical'
#     return fn
# }


# # [Row] -> Value
# dw.metric = {
#   count: (alias) ->
#     fn = (rows) -> rows.length
#     fn.alias = alias or 'count'
#     return fn

#   sum: (column, alias) ->
#     fn = (rows) -> sum(rows, column)
#     fn.alias = alias or column
#     return fn

#   average: (column, alias) ->
#     fn = (rows) -> if rows.length then sum(rows, column) / rows.length else 0
#     fn.alias = alias or column
#     return fn
# }

# dw.sort = (column, dir, limit) -> (rows) ->
#   return rows unless rows.length

#   if typeof rows[0][column] is 'string'
#     if dir is 'asc'
#       compare = (a,b) -> a[column].localeCompare(b[column])
#     else
#       compare = (a,b) -> b[column].localeCompare(a[column])
#   else
#     if dir is 'asc'
#       compare = (a,b) -> a[column] - b[column]
#     else
#       compare = (a,b) -> b[column] - a[column]

#   rows.sort(compare)

#   if limit?
#     rows = rows.slice(0, limit)

#   return rows


# dw.sac = (split, apply, combine) ->
#   apply = [apply] if typeof apply is 'function'
#   fn = (rows) ->
#     buckets = {}

#     console.log 'wop', split.alias, apply.map((f) -> f.alias)

#     for row, i in rows
#       bucket = split(row, i)
#       if buckets[bucket]
#         buckets[bucket].push(row)
#       else
#         buckets[bucket] = [row]

#     aggs = []
#     for bucket, bucketRows of buckets
#       agg = {}
#       agg[split.alias] = bucket
#       for ap in apply
#         agg[ap.alias] = ap(bucketRows, bucket)
#       aggs.push(agg)

#     return combine(aggs)

#   fn.alias = '$break'
#   return fn

colors = "#1f77b4 #aec7e8 #ff7f0e #ffbb78 #2ca02c #98df8a #d62728 #ff9896 #9467bd #c5b0d5 #8c564b #c49c94 #e377c2 #f7b6d2 #7f7f7f #c7c7c7 #bcbd22 #dbdb8d #17becf #9edae5".split(' ')

data = do ->
  pick = (arr) -> arr[Math.floor(Math.random() * arr.length)]

  now = Date.now()
  return d3.range(200).map (i) ->
    return {
      Time: new Date(now - i * 57 * 1000)
      Letter: pick('ABCDEFGHIJ')
      Number: pick('123456')
      ScoreA: 100 * Math.random() * Math.random()
      ScoreB: 10 * Math.random()
    }

columns = [
  'Time'
  'Letter'
  'Number'
  'ScoreA'
  'ScoreB'
]

cloneRow = (d) ->
  nd = {}
  for k,v of d
    continue if k[0] is '$'
    nd[k] = v
  return nd

make_anim_table = ({selector, data, columns, keyColumn, grouped, width, height, zoomedOut, split}) ->
  columns = dvl.wrap(columns)

  buckets = dvl()
  bucketedData = dvl()

  dvl.register {
    listen: [data, split]
    change: [buckets, bucketedData]
    fn: ->
      _data = data.value()
      _split = split.value() ? -> 'ALL'

      _buckets = []
      _bucketedData = []
      bucketMap = {}
      for d in data
        bucketKey = _split(d)
        bucket = bucketMap[bucketKey]
        if not bucket
          bucketIdx = _buckets.length
          bucket = {
            key: bucketKey
            color: colors[bucketIdx % colors.length]
            idx: bucketIdx
            size: 0
          }
          _buckets.push(bucket)
          bucketMap[bucketKey] = bucket

        nd = cloneRow(d)
        nd['$bucket'] = bucket
        bucket.size++
        _bucketedData.push(nd)

      buckets.value(_buckets)
      bucketedData.value(_bucketedData)
      return

  svg = dvl.bind {
    parent: d3.select(selector)
    self: 'div.table'
  }

  columnWidth = dvl.apply [width, columns], (width, columns) -> width / columns.length
  rowHeight = dvl.apply [height, bucketedData, zoomedOut], (height, data, zoomedOut) -> if zoomedOut then Math.ceil(height / data.length) else 28

  op_multiply = dvl.op((x,y) -> x*y)
  op_px = dvl.op((x) -> "#{x}px")

  rows = dvl.bind {
    parent: svg
    self: 'div.row'
    data: bucketedData
    join: dvl.acc(keyColumn)
    style: {
      left: '0px'
      top: rowHeight.apply((rh) -> (d,i) -> (d.$bucket.idx * 5 + i * rh) + 'px')
      width: op_px(width)
      height: op_px(rowHeight)
      background: -> if Math.random() > 0.5 then 'red' else 'green'
    }
    transition: {
      duration: 1000
    }
  }

  cols = dvl.bind {
    parent: rows
    self: 'div.column'
    data: columns.apply((columns) -> (row) -> columns.map((c) -> row[c]))
    style: {
      width: op_px(columnWidth)
    }
    text: String
  }

  return


zoomedOut = dvl(false)

make_anim_table {
  selector: 'body'
  data
  columns
  keyColumn: columns[0]
  grouped: false
  width: 100 * columns.length
  height: 800
  zoomedOut
  groupBy: (d) -> d['Letter']
}

window.zoom = ->
  zoomedOut.value(!zoomedOut.value())
  return


window.dbg = (str) -> eval(str)










