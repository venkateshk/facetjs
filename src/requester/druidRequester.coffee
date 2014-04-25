request = require('request')

module.exports = ({locator, timeout}) ->
  timeout or= 60000
  return ({context, query}, callback) ->
    locator (err, location) ->
      if err
        callback(err)
        return

      url = "http://#{location.host}:#{location.port ? 8080}/druid/v2/"
      if query.queryType is 'introspect'
        param = {
          method: 'GET'
          url: url + "datasources/#{query.dataSource}"
          json: true
          timeout
        }
      else
        postfix = ''
        postfix += 'heatmap' if query.queryType is 'heatmap' # Druid is f-ed
        postfix += '?pretty' if context?.pretty
        param = {
          method: 'POST'
          url: url + postfix
          json: query
          timeout
        }

      request(param, (err, response, body) ->
        if err
          err.query = query
          callback(err)
          return

        if response.statusCode isnt 200
          err = new Error("Bad status code")
          err.query = query
          callback(err)
          return

        if Array.isArray(body) and not body.length
          # response is [] which can mean 'no data matches filters' or 'no data source' lets find out which!
          request({
            method: 'GET'
            url: url + "datasources"
            json: true
            timeout
          }, (err, response, body) ->
            if err
              err.dataSource = query.dataSource
              callback(err)
              return

            if response.statusCode isnt 200 or not Array.isArray(body)
              err = new Error("Bad response")
              err.dataSource = query.dataSource
              callback(err)
              return

            if query.dataSource not in body
              err = new Error("No such datasource")
              err.dataSource = query.dataSource
              callback(err)
              return

            callback(null, []) # Wow actual [] !
            return
          )
          return

        callback(null, body)
        return
      )

    return

