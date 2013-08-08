facet.ajaxPoster = ({url, context, prety}) -> (request, callback) ->
  if request.query not instanceof FacetQuery
    callback(new TypeError("query must be a FacetQuery"))
    return

  return $.ajax({
    url
    type: 'POST'
    dataType: 'json'
    contentType: 'application/json'
    data: JSON.stringify({
      context
      query: request.query.valueOf()
    }, null, if prety then 2 else null)
    success: (res) ->
      callback(null, res)
      return
    error: (xhr) ->
      text = xhr.responseText
      try
        err = JSON.parse(text)
      catch e
        err = { message: text }
      callback(err, null)
      return
  })

facet.verboseDriver = (driver) -> (query, callback) ->
  console.log('Query:', query)
  driver(query, (err, res) ->
    console.log('Result:', res)
    callback(err, res)
    return
  )
  return
