exports.ajax = ({url, context, prety}) ->
  posterContext = context
  return (request, callback) ->
    {context, query} = request
    context or= {}
    for own k, v of posterContext
      context[k] = v
    return $.ajax({
      url
      type: 'POST'
      dataType: 'json'
      contentType: 'application/json'
      data: JSON.stringify({
        context
        query: query.valueOf()
      }, null, if prety then 2 else null)
      success: (res) ->
        callback(null, res)
        return
      error: (xhr) ->
        text = xhr.responseText
        try
          err = JSON.parse(text)
        catch e
          err = { message: text }
        callback(err, null)
        return
    })


exports.worker = ({url, params, numWorkers}) ->
  numWorkers or= 1
  queue = []
  workers = []

  onWorkerError = (e) ->
    console.log("WORKER ERROR: Line #{e.lineno} in #{e.filename}: #{e.message}")
    return

  onMessage = (e) ->
    type = e.data.type
    if type is 'ready'
      @__ready__ = true
      tryToProcess()
      return

    throw new Error("something went horribly wrong") unless @__callback__
    if type is 'error'
      @__callback__(e.data.error)
    else if type is 'result'
      @__callback__(null, e.data.result)
    else
      throw new Error("unexpected message type '#{type}' from worker")

    @__callback__ = null
    tryToProcess()
    return

  while workers.length < numWorkers
    worker = new Worker(url)
    worker.__ready__ = false
    worker.__callback__ = null
    worker.addEventListener('error', onWorkerError, false)
    worker.addEventListener('message', onMessage, false)
    workers.push(worker)

  sendParams = ->
    return if paramError
    for worker in workers
      worker.postMessage({
        type: 'params'
        params: paramValues
      })
    return

  paramError = null
  paramValues = null
  if typeof params is 'function'
    params (err, pv) ->
      paramError = err
      paramValues = pv
      sendParams()
      return
  else
    paramValues = params
    sendParams()

  findAvailableWorker = ->
    for worker in workers
      return worker if worker.__ready__ and not worker.__callback__
    return null

  tryToProcess = ->
    return unless queue.length

    # There has been a param error, deny everything
    if paramError
      callback(paramError) for [request, callback] in queue
      return

    # Make sure the worker is ready and available
    worker = findAvailableWorker()
    return unless worker

    [request, callback] = queue.shift()

    worker.__callback__ = callback
    worker.postMessage({
      type: 'request'
      request: {
        context: request.context
        query: request.query.valueOf()
      }
    })
    return

  return (request, callback) ->
    queue.push([request, callback])
    tryToProcess()
    return


exports.verbose = (driver) -> (query, callback) ->
  console.log('Query:', query)
  driver(query, (err, res) ->
    console.log('Result:', res)
    callback(err, res)
    return
  )
  return
