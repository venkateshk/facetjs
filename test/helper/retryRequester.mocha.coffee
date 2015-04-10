{ expect } = require("chai")

Q = require('q')

facet = require("../../build/facet")
{ retryRequester } = facet.helper

describe "Retry requester", ->
  makeRequester = (failNumber, isTimeout) ->
    return (request) ->
      if failNumber > 0
        failNumber--
        return Q.reject(new Error(if isTimeout then 'timeout' else 'some error'))
      else
        return Q([1, 2, 3])


  it "no retry needed (no fail)", (testComplete) ->
    testRequester = retryRequester({
      requester: makeRequester(0)
      delay: 50
      retry: 2
    })

    testRequester({}).then((res) ->
      expect(res).to.be.an('array')
      testComplete()
    ).done()

  it "one fail", (testComplete) ->
    testRequester = retryRequester({
      requester: makeRequester(1)
      delay: 50
      retry: 2
    })

    testRequester({}).then((res) ->
      expect(res).to.be.an('array')
      testComplete()
    ).done()

  it "two fails", (testComplete) ->
    testRequester = retryRequester({
      requester: makeRequester(2)
      delay: 50
      retry: 2
    })

    testRequester({}).then((res) ->
      expect(res).to.be.an('array')
      testComplete()
    ).done()

  it "three fails", (testComplete) ->
    testRequester = retryRequester({
      requester: makeRequester(3)
      delay: 50
      retry: 2
    })

    testRequester({})
      .then(-> throw new Error('DID_NOT_THROW'))
      .catch((err) ->
        expect(err.message).to.equal('some error')
        testComplete()
      ).done()

  it "timeout", (testComplete) ->
    testRequester = retryRequester({
      requester: makeRequester(1, true)
      delay: 50
      retry: 2
    })

    testRequester({})
      .then(-> throw new Error('DID_NOT_THROW'))
      .catch((err) ->
        expect(err.message).to.equal('timeout')
        testComplete()
      ).done()
