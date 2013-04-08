http = require('http')

module.exports = ({host, port, path}) ->
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
        callback({
          error: 'close'
          message: err
        })
        return

      response.on 'end', ->
        chunks = chunks.join('')
        if response.statusCode isnt 200
          callback({
            error: 'bad status code'
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

    req.write(druidQuery.toString('utf-8'))
    req.end()
    return

