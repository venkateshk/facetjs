request = require('request')

postQuery = ({url, query, timeout}, callback) ->
  request({
    method: 'POST'
    url: url + '/job'
    query
    timeout
  }, (err, response, body) ->
    if err
      callback(err)
      return

    if response.statusCode isnt 200
      callback(new Error("Bad status code"))
      return

    job = body.job
    if typeof job isnt 'string'
      callback(new Error('Bad job ID'))
      return

    callback(null, job)
    return
  )
  return


checkJobStatus = ({url, job, timeout}, callback) ->
  request({
    method: 'GET'
    url: url + "/job/#{job}"
    json: true
    timeout
  }, (err, response, body) ->
    if err
      callback(err)
      return

    if response.statusCode isnt 200
      callback(new Error("Bad status code"))
      return

    if typeof body.job is 'undefined'
      callback(null, null)
      return

    if typeof body.exceptionMessage is 'string'
      callback(new Error(body.exceptionMessage))
      return

    if not Array.isArray(body.results)
      callback(new Error("unexpected result"))

    callback(null, body.results)
    return
  )
  return


module.exports = ({locator, timeout, refresh}) ->
  refresh or= 5000
  timeout or= 60000

  return ({context, query}, callback) ->
    locator (err, location) ->
      if err
        callback(err)
        return

      url = "http://#{location.host}:#{location.port ? 8080}"

      postQuery {
        url
        query
        timeout
      }, (err, job) ->
        if err
          callback(err)
          return

        pinger = setInterval((->
          checkJobStatus {
            url
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
