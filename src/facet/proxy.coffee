facet.ajaxPoster = ({url, context, prety}) -> (query, callback) ->
  return $.ajax({
    url
    type: 'POST'
    dataType: 'json'
    contentType: 'application/json'
    data: JSON.stringify({ context, query }, null, if prety then 2 else null)
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