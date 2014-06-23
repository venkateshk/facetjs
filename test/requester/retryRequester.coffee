{ expect } = require("chai")

retryRequester = require('../../src/requester/retryRequester')

describe "Retry requester", ->
  makeRequester = (failNumber, isTimeout) ->
    return (request, callback) ->
      if failNumber > 0
        failNumber--
        callback(new Error(if isTimeout then 'timeout' else 'some error'))
      else
        callback(null, [1, 2, 3])
      return

  it "no retry needed (no fail)", (done) ->
    testRequester = retryRequester({
      requester: makeRequester(0)
      retry: 2
    })

    testRequester {}, (err, res) ->
      expect(err).to.not.exist
      expect(res).to.be.an('array')
      done()

  it "one fail", (done) ->
    testRequester = retryRequester({
      requester: makeRequester(1)
      retry: 2
    })

    testRequester {}, (err, res) ->
      expect(err).to.not.exist
      expect(res).to.be.an('array')
      done()

  it "two fails", (done) ->
    testRequester = retryRequester({
      requester: makeRequester(2)
      retry: 2
    })

    testRequester {}, (err, res) ->
      expect(err).to.not.exist
      expect(res).to.be.an('array')
      done()

  it "three fails", (done) ->
    testRequester = retryRequester({
      requester: makeRequester(3)
      retry: 2
    })

    testRequester {}, (err, res) ->
      expect(err.message).to.equal('some error')
      done()

  it "timeout", (done) ->
    testRequester = retryRequester({
      requester: makeRequester(1, true)
      retry: 2
    })

    testRequester {}, (err, res) ->
      expect(err.message).to.equal('timeout')
      done()

















