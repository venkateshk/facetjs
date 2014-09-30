{EventEmitter} = require('events')
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

makeManagerForPath = (client, path, emitter, dataExtractor, locatorTimeout) ->
  next = -1
  pool = null
  queue = []

  dispatch = (callback) ->
    throw new Error('get next called on loading pool') unless pool
    if pool.length
      next++
      callback(null, pool[next % pool.length])
    else
      callback(new Error('Empty pool'))

  processQueue = ->
    dispatch(queue.shift()) while queue.length
    return

  onGetChildren = (err, children) ->
    if err
      console.log('Failed to list children of %s due to: %s.', path, err) if debug
      emitter.emit('childListFail', path, err)
      pool = []
      processQueue()
      return

    async.map(
      children
      (child, callback) ->
        client.getData(path + '/' + child, (err, data) ->
          if err
            if err.getCode() is Exception.NO_NODE
              callback(null, null)
            else
              emitter.emit('nodeDataFail', path, err)
              callback(null, null)
            return

          callback(null, dataExtractor(data.toString('utf8')))
          return
        )

      (err, newPool) ->
        pool = newPool.filter(Boolean)
        emitter.emit('newPool', path, pool)
        processQueue()
        return
    )
    return

  onChange = (event) ->
    console.log('Got watcher event: %s', event) if debug
    emitter.emit('change', path, event)
    client.getChildren(path, onChange, onGetChildren)
    return

  client.getChildren(path, onChange, onGetChildren)

  return (callback) ->
    if pool
      dispatch(callback)
      return

    queue.push(callback)

    if locatorTimeout
      setTimeout((->
        return unless callback in queue
        queue = queue.filter((c) -> c isnt callback)
        callback(new Error('Timeout'))
      ), locatorTimeout)
    return


# connectionTimeout, The timeout for individual locators
# sessionTimeout, Session timeout in milliseconds, defaults to 30 seconds.
# spinDelay, The delay (in milliseconds) between each connection attempts.
# retries, The number of retry attempts for connection loss exception.
module.exports = ({servers, dataExtractor, locatorTimeout, sessionTimeout, spinDelay, retries}) ->
  dataExtractor or= defaultDataExtractor
  locatorTimeout or= 2000
  client = zookeeper.createClient(servers, {
    sessionTimeout
    spinDelay
    retries
  })

  emitter = new EventEmitter()
  active = false
  activate = ->
    return if active
    client.on('connected', ->    emitter.emit('connected'))
    client.on('disconnected', -> emitter.emit('disconnected'))
    client.on('expired', ->      emitter.emit('expired'))
    client.connect()
    active = true
    return

  pathManager = {}
  emitter.manager = (path) ->
    throw new TypeError('path must be a string') unless typeof path is 'string'
    path = '/' + path if path[0] isnt '/'
    activate()
    pathManager[path] or= makeManagerForPath(client, path, emitter, dataExtractor, locatorTimeout)
    return pathManager[path]

  return emitter
