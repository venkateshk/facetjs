"use strict"

exports.ajax = ({url, context, prety}) ->
  posterContext = context
  return (request, callback) ->
    {context, query} = request
    context or= {}
    for own k, v of posterContext
      context[k] = v
    return $.ajax({
      url
      type: 'POST'
      dataType: 'json'
      contentType: 'application/json'
      data: JSON.stringify({
        context
        query: query.valueOf()
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
