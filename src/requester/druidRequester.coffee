http = require('http')

module.exports = ({host, port, timeout}) ->
  return ({context, query}, callback) ->
    callbacked = false
    path = '/druid/v2/'
    if query.queryType is 'heatmap'
      # Druid is f-ed
      path += 'heatmap'

    path += '?pretty' if context?.pretty

    queryBuffer = new Buffer(JSON.stringify(query), 'utf-8')
    opts = {
      host
      port
      path
      method: 'POST'
      headers: {
        'Content-Type': 'application/json'
        'Content-Length': queryBuffer.length
      }
    }
    req = http.request(opts, (response) ->
      # response.statusCode
      # response.headers
      # response.statusCode

      response.setEncoding('utf8')
      chunks = []
      response.on 'data', (chunk) ->
        chunks.push(chunk)
        return

      response.on 'close', (err) ->
        return if callbacked
        callback({
          error: 'close'
          message: err
        })
        callbacked = true
        return

      response.on 'end', ->
        chunks = chunks.join('')
        if response.statusCode isnt 200
          return if callbacked
          callback({
            error: 'bad status code'
            detail: response.statusCode
            message: chunks
          })
          callbacked = true
          return

        try
          chunks = JSON.parse(chunks)
        catch e
          return if callbacked
          callback({
            error: 'json parse'
            message: e.message
          })
          callbacked = true
          return

        return if callbacked
        callback(null, chunks)
        callbacked = true
        return
      return
    )

    if timeout
      req.on 'socket', (socket) ->
        socket.setTimeout(timeout)
        socket.on 'timeout', -> req.abort()

    req.on 'error', (e) ->
      return if callbacked
      callback(e)
      callbacked = true
      return

    req.write(queryBuffer.toString('utf-8'))
    req.end()
    return

