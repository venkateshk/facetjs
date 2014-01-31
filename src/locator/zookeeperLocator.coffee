async = require('async')
zookeeper = require('node-zookeeper-client')
{Exception} = zookeeper

debug = false

defaultDataExtractor = (data) ->
  try
    data = JSON.parse(data)
  catch e
    return null

  return null unless data.address and data.port

  return {
    host: data.address
    port: data.port
  }

makeManagerForPath = (client, path, dataExtractor) ->
  next = -1
  pool = null
  queue = []

  onGetChildren = (err, children) ->
    if err
      console.log('Failed to list children of %s due to: %s.', path, err) if debug
      pool = []
      processQueue()
      return

    console.log('Children of %s are: %j.', path, children) if debug
    async.map(
      children
      (child, callback) ->
        client.getData(path + '/' + child, (err, data) ->
          if err
            if err.getCode() is Exception.NO_NODE
              callback(null, null)
            else
              console.log(err.stack) if debug
              callback(null, null) #?
            return

          callback(null, dataExtractor(data.toString('utf8')))
          return
        )

      (err, newPool) ->
        pool = newPool.filter(Boolean)
        processQueue()
        return
    )
    return

  onChange = (event) ->
    console.log('Got watcher event: %s', event) if debug
    client.getChildren(path, onChange, onGetChildren)
    return

  client.getChildren(path, onChange, onGetChildren)

  dispatch = (callback) ->
    throw new Error('get next called on loading pool') unless pool
    if pool.length
      next++
      callback(null, pool[next % pool.length])
    else
      callback(new Error('empty pool'))

  processQueue = ->
    dispatch(queue.shift()) while queue.length
    return

  return (callback) ->
    if pool is null
      queue.push(callback)
    else
      dispatch(callback)
    return


# sessionTimeout, Session timeout in milliseconds, defaults to 30 seconds.
# spinDelay, The delay (in milliseconds) between each connection attempts.
# retries, The number of retry attempts for connection loss exception.
module.exports = ({servers, dataExtractor, sessionTimeout, spinDelay, retries}) ->
  dataExtractor or= defaultDataExtractor
  client = zookeeper.createClient(servers, {
    sessionTimeout
    spinDelay
    retries
  })
  active = false

  pathManager = {}

  return (path) ->
    throw new TypeError('path must be a string') unless typeof path is 'string'
    path = '/' + path if path[0] isnt '/'

    if not active
      client.on('connected', ->
        console.log('Connected to ZooKeeper.') if debug
        return
      )
      client.on('disconnected', ->
        console.log('Dosconnected from ZooKeeper.') if debug
        return
      )
      client.connect()
      active = true

    pathManager[path] or= makeManagerForPath(client, path, dataExtractor)
    return pathManager[path]

