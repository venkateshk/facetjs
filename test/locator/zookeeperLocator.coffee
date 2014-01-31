chai = require("chai")
expect = chai.expect

async = require('async')
zookeeper = require('node-zookeeper-client')
CreateMode = zookeeper.CreateMode

zookeeperLocator = require('../../src/locator/zookeeperLocator')({
  servers: 'localhost:2181/discovery'
})

zkClient = zookeeper.createClient(
  'localhost:2181',
  {
    sessionTimeout: 10000
    spinDelay : 1000
    retries : 0
  }
)

createNode = (node, guid, obj, callback) ->
  zkClient.mkdirp(
    "/discovery/#{node}/#{guid}"
    new Buffer(JSON.stringify(obj))
    CreateMode.EPHEMERAL
    (error, path) ->
      if error
        console.log(error.stack)
        callback(error)
        return

      callback(null)
      return
  )
  return

removeNode = (node, guid, callback) ->
  zkClient.remove("/discovery/#{node}/#{guid}", callback)
  return

zkClient.connect()

setInterval((->
  console.log 'State:', zkClient.getState()
), 1000)

getN = (n, locator, callback) ->
  locations = []
  async.whilst(
    -> locations.length < n
    (callback) ->
      locator (err, location) ->
        if err
          callback(err)
          return

        locations.push(location.host + ':' + location.port)
        callback()
        return
    (err) -> callback(err, locations.sort())
  )

describe 'Zookeeper locator', ->
  @timeout 60000
  myServiceLocator = null
  otherServiceLocator = null

  before (done) ->
    async.series([
      (callback) -> createNode('my:service', 'fake-guid-1-1', { address: '10.10.10.10', port: 8080 }, callback)
      (callback) -> createNode('my:service', 'fake-guid-1-2', { address: '10.10.10.20', port: 8080 }, callback)
      (callback) -> createNode('my:service', 'fake-guid-1-3', { address: '10.10.10.30', port: 8080 }, callback)
      (callback) ->
        myServiceLocator = zookeeperLocator('my:service')
        callback()
    ], done)

  it "is memoized by path", ->
    expect(myServiceLocator).to.equal(zookeeperLocator('/my:service'))

  it "correct init run", (done) ->
    getN 3, myServiceLocator, (err, locations) ->
      expect(err).to.not.exist
      expect(locations).to.deep.equal([
        '10.10.10.10:8080'
        '10.10.10.20:8080'
        '10.10.10.30:8080'
      ])
      done()

  it "works after removing a node", (done) ->
    async.series([
      (callback) -> removeNode('my:service', 'fake-guid-1-1', callback)
      (callback) -> setTimeout(callback, 50) # delay a little bit
    ], (err) ->
      expect(err).to.not.exist
      getN 2, myServiceLocator, (err, locations) ->
        expect(err).to.not.exist
        expect(locations).to.deep.equal([
          '10.10.10.20:8080'
          '10.10.10.30:8080'
        ])
        done()
    )

  it "works after adding a node", (done) ->
    async.series([
      (callback) -> createNode('my:service', 'fake-guid-1-4', { address: '10.10.10.40', port: 8080 }, callback)
      (callback) -> setTimeout(callback, 50) # delay a little bit
    ], (err) ->
      expect(err).to.not.exist
      getN 3, myServiceLocator, (err, locations) ->
        expect(err).to.not.exist
        expect(locations).to.deep.equal([
          '10.10.10.20:8080'
          '10.10.10.30:8080'
          '10.10.10.40:8080'
        ])
        done()
    )

  it "works after removing the remaining nodes", (done) ->
    async.series([
      (callback) -> removeNode('my:service', 'fake-guid-1-2', callback)
      (callback) -> removeNode('my:service', 'fake-guid-1-3', callback)
      (callback) -> removeNode('my:service', 'fake-guid-1-4', callback)
      (callback) -> setTimeout(callback, 50) # delay a little bit
    ], (err) ->
      myServiceLocator (err, location) ->
        expect(err).to.exist
        done()
    )



