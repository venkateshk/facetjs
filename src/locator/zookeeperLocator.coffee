zkplus  = require 'zkplus'

module.exports = ({servers, path}) ->
  client = zkplus.createClient({
    servers
  })

  client.on('connect', ->
    client.get('/prod/discovery/druid:prod:bard', (err, obj) ->
      if err
        throw err

      console.log 'resp', obj
      return
    )
    return
  )
