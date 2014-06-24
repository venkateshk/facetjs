"use strict"

backoff = require 'backoff'

module.exports = ({requester, retry, retryOnTimout}) ->
  throw new TypeError("retry should be a number") unless typeof retry is 'number'

  requestBackoff = backoff.exponential()
  requestBackoff.failAfter(retry)

  return ({query, context}, callback) ->
    requestBackoff.on('ready', (number, delay) ->
      requester({
        context
        query
      }, (err, res) ->
        if err
          if err.message is 'timeout' and not retryOnTimout
            requestBackoff.reset()
            callback(err)
          else
            requestBackoff.backoff(err)
          return

        requestBackoff.reset()
        callback(null, res)
        return
      )
      return
    )

    requestBackoff.on('fail', (err) ->
      callback(err)
      return
    )

    requestBackoff.backoff()
    return
