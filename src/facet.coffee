copyHere = (subModule) ->
  exports[k] = v for k, v of subModule
  return

copyHere(require('./query'))
exports.driver = require('./driver')
copyHere(require('./render'))

facet.WallTime = require('../lib/walltime')

# Temp hack
exports.d3 = require('d3')
