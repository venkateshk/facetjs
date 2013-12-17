{FacetQuery} = require('../query')

module.exports = (driverFn) ->
  driver = null

  onMessage = (e) ->
    switch e.data.type
      when 'params'
        driver = driverFn(e.data.params)
        postMessage({ type: 'ready' })

      when 'request'
        throw new Error('request received before params') unless driver

        {context, query} = e.data.request
        try
          query = new FacetQuery(query)
        catch e
          postMessage({
            type: 'error'
            error: { message: e.message }
          })
          return

        driver({context, query}, (err, res) ->
          if err
            postMessage({
              type: 'error'
              error: err
            })
          else
            postMessage({
              type: 'result'
              result: res
            })
          return
        )

      else
        throw new Error("unexpected message type '#{type}' from manager")

    return

  self.addEventListener('message', onMessage, false)
