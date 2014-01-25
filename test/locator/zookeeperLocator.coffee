zookeeperLocator = require('../../src/locator/zookeeperLocator')

zookeeperLocator({
  servers: [
    { host: '10.140.17.215', port: 2181 }
    # { host: '10.6.134.41',   port: 2181 }
    # { host: '10.4.214.175',  port: 2181 }
  ]
})
