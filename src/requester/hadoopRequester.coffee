http = require('http')

postQuery = ({host, port, query, timeout}, callback) ->
  queryBuffer = new Buffer(JSON.stringify(query), 'utf-8')
  opts = {
    host
    port
    path: '/job'
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

      console.log "GOT (POST)", chunks

      job = chunks.job
      if typeof job isnt 'string'
        callback(new Error('no job id'))
        return

      callback(null, job)
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

  console.log('Sending', JSON.stringify(query, null, 2))
  req.write(queryBuffer.toString('utf-8'))
  req.end()
  return


checkJobStatus = ({host, port, job, timeout}, callback) ->
  opts = {
    host
    port
    path: "/job/#{job}"
    method: 'GET'
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

      console.log "GOT (GET)", chunks

      if typeof chunks.job is 'undefined'
        callback(null, null)
        return

      if typeof chunks.exceptionMessage is 'string'
        callback(new Error(chunks.exceptionMessage))
        return

      if not Array.isArray(chunks.results)
        callback(new Error("unexpected result"))

      callback(null, chunks.results)
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

  req.end()
  return


module.exports = ({locator, timeout, refresh}) ->
  refresh or= 5000

  return ({context, query}, callback) ->
    locator (err, location) ->
      if err
        callback(err)
        return

      { host, port } = location
      port ?= 8080

      postQuery {
        host
        port
        query
        timeout
      }, (err, job) ->
        if err
          callback(err)
          return

        pinger = setInterval((->
          checkJobStatus {
            host
            port
            job
            timeout
          }, (err, results) ->
            if err
              clearInterval(pinger)
              callback(err)
              return

            if results
              clearInterval(pinger)
              callback(null, results)
              return

            return

          return
        ), refresh)

        return

    return
