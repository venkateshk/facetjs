http = require('http')

module.exports = ({host, port, timeout}) ->
  return ({context, query}, callback) ->
    queryBuffer = new Buffer(JSON.stringify(query), 'utf-8')
    opts = {
      host
      port
      path: '/'
      method: 'POST'
      headers: {
        'Content-Type': 'application/json'
        'Content-Length': queryBuffer.length
      }
    }
    req = http.request(opts, (response) ->
      hasEnded = false
      # response.statusCode
      # response.headers
      # response.statusCode

      response.setEncoding('utf8')
      chunks = []
      response.on 'data', (chunk) ->
        chunks.push(chunk)
        return

      response.on 'close', (err) ->
        return if hasEnded
        callback({
          error: 'close'
          message: err
        })
        return

      response.on 'end', ->
        hasEnded = true
        chunks = chunks.join('')
        if response.statusCode isnt 200
          callback({
            error: 'bad status code'
            detail: response.statusCode
            message: chunks
          })
          return

        try
          chunks = JSON.parse(chunks)
        catch e
          callback({
            error: 'json parse'
            message: e.message
          })
          return

        callback(null, chunks)
        return
      return
    )

    if timeout
      req.on 'socket', (socket) ->
        socket.setTimeout(timeout)
        socket.on 'timeout', -> req.abort()

    req.on 'error', (e) ->
      callback(e)
      return

    req.write(queryBuffer.toString('utf-8'))
    req.end()
    return
