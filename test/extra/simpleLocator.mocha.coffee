{ expect } = require("chai")

facet = require("../../build/facet")
{ simpleLocator } = facet.extra

describe 'Simple locator', ->
  describe 'shortcut function', ->
    locator = simpleLocator("localhost:8080")

    it "works", (testComplete) ->
      locator()
      .then((location) ->
        expect(location).to.deep.equal({
          hostname: 'localhost'
          port: 8080
        })
        testComplete()
      ).done()

  describe 'full option function', ->
    locator = simpleLocator({
      resource: "localhost;koalastothemax.com:80"
      defaultPort: 8181
    })

    it "works", (testComplete) ->
      locator()
      .then((location) ->
        for i in [1..20]
          if location.hostname is 'localhost'
            expect(location).to.deep.equal({
              hostname: 'localhost'
              port: 8181
            })
          else
            expect(location).to.deep.equal({
              hostname: 'koalastothemax.com'
              port: 80
            })
        testComplete()
      ).done()
