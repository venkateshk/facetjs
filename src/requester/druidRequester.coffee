http = require('http')

module.exports = ({locator, timeout}) ->
  return ({context, query}, callback) ->
    locator (err, location) ->
      if err
        callback(err)
        return

      if query.queryType is 'introspect'
        path = "/druid/v2/datasources/#{query.dataSource}"
        method = 'GET'
        headers = null
      else
        path = '/druid/v2/'
        path += 'heatmap' if query.queryType is 'heatmap' # Druid is f-ed
        path += '?pretty' if context?.pretty
        method = 'POST'
        queryBuffer = new Buffer(JSON.stringify(query), 'utf-8')
        headers = {
          'Content-Type': 'application/json'
          'Content-Length': queryBuffer.length
        }

      req = http.request({
        host: location.host
        port: location.port ? 8080
        path
        method
        headers
      }, (response) ->
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
          callback(err)
          return

        response.on 'end', ->
          hasEnded = true
          chunks = chunks.join('')
          if response.statusCode isnt 200
            err = new Error('bad status code')
            err.statusCode = response.statusCode
            err.body = chunks
            callback(err)
            return

          try
            chunks = JSON.parse(chunks)
          catch e
            callback(e)
            return

          callback(null, chunks)
          return
        return
      )

      # ToDo: verify this with tests!
      if timeout
        req.on 'socket', (socket) ->
          socket.setTimeout(timeout)
          socket.on 'timeout', -> req.abort()

      req.on 'error', (e) ->
        callback(e)
        return

      req.write(queryBuffer.toString('utf-8')) if query.queryType isnt 'introspect'
      req.end()
      return

    return

