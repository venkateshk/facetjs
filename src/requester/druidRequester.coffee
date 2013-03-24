http = require('http')

exports.requester = ({host, port, path}) ->
  opts = {
    host
    port
    path
    method: 'POST'
    headers: {
      'content-type': 'application/json'
    }
  }
  return (druidQuery, callback) ->
    druidQuery = new Buffer(JSON.stringify(druidQuery), 'utf-8')
    opts.headers['content-length'] = druidQuery.length
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
        console.log 'CLOSE'
        return

      response.on 'end', ->
        chunks = chunks.join('')
        if response.statusCode isnt 200
          callback(chunks, null)
          return

        try
          chunks = JSON.parse(chunks)
        catch e
          callback(e, null)
          return

        callback(null, chunks)
        return
      return
    )

    req.write(druidQuery.toString('utf-8'))
    req.end()
    return

