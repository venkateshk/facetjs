makeFunction = (str) -> eval("(" + str + ")")

makeIterator = (array) ->
  pos = 0
  return {
    hasNext: -> pos < array.length
    next: -> array[pos++]
  }

# {
#   datasets: [
#     {
#       name: "main"
#       path: "s3://wikipedia_editstream-alpha"
#       intervals: ["2013-12-01/2013-12-02"],
#       // RawEvent => Boolean
#       filter: "function(datum) { return datum.cut === 'Ideal'; }"
#     }
#   ]
#   // RawEvent => String
#   split: {
#     name: 'Color'
#     fn: "function(thing) { return thing.datum.color; }"
#   }
#   // Iterator => Dict
#   applies: "function(iterator) {
#     var sumPrice = 0
#     var sumVolume = 0
#     while(thing = iterator.next()) {
#       sumPrice += thing.datum.price;
#       sumVolume += thing.datum.volume;
#     }
#     return {
#       'TotalPrice': sumPrice
#       'TotalVolume': sumVolume
#       'Ratio': sumPrice/sumVolume
#     };
#   }"
#   combine: {
#     limit: 5
#     comparator: "function(d1,d2) { return d2.revenue - d1.revenue }"
#   }
# }

module.exports = (data, debug) ->
  return ({context, query}, callback) ->
    { datasets, split, applies, combine } = query

    console.log("Querying:", JSON.stringify(query, null, 2)) if debug

    # Ignore intervals (for now)
    raws = []
    for {name, filter} in datasets
      filterFn = makeFunction(filter)
      for datum in data when filterFn(datum)
        raws.push {
          dataset: name
          datum
        }


    splitValues = {}
    buckets = {}
    if split
      splitFn = makeFunction(split.fn)
      for raw in raws
        splitValue = splitFn(raw)
        hash = String(splitValue)
        if not buckets[hash]
          splitValues[hash] = splitValue
          buckets[hash] = []
        buckets[hash].push(raw)
    else
      buckets[''] = raws


    list = []
    appliesFn = makeFunction(applies)
    for hash, bucket of buckets
      prop = appliesFn(makeIterator(bucket))
      prop[split.name] = splitValues[hash] if split
      list.push(prop)

    if combine
      comparatorFn = makeFunction(combine.comparator)
      list.sort(comparatorFn)
      if combine.limit?
        list = list.slice(0, combine.limit)

    console.log('Returning:', list) if debug
    callback(null, list)
    return
