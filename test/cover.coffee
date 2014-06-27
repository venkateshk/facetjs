require('coffee-coverage').register({
  path: 'relative'
  basePath: __dirname + "/../src/"
  exclude: ['/render'] # (for now)
  initAll: true
})
