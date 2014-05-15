request = require('request')

module.exports = ({locator, timeout}) ->
  return ({context, query}, callback) ->
    locator (err, location) ->
      if err
        callback(err)
        return

      url = "http://#{location.host}:#{location.port ? 8080}/druid/v2/"
      if query.queryType is 'introspect'
        dataSourceString = if query.dataSource.type is 'union' then query.dataSource.dataSources[0] else query.dataSource
        param = {
          method: 'GET'
          url: url + "datasources/#{dataSourceString}"
          json: true
          timeout
        }
      else
        param = {
          method: 'POST'
          url: url + if context?.pretty then '?pretty' else ''
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

        # Druid returns {"dimensions":[],"metrics":[]} for data sources it does not know
        if query.queryType is 'introspect' and body.dimensions?.length is 0 and body.metrics?.length is 0
          err = new Error("No such datasource")
          err.dataSource = query.dataSource
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

            queryDataSources = if query.dataSource.type is 'union' then query.dataSource.dataSources else [query.dataSource]
            if queryDataSources.every((dataSource) -> dataSource not in body)
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

