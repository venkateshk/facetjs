FacetVis = require('./facetVis')

exports.version = '0.5.0'

exports.filter = require('./filter')
exports.split = require('./split')
exports.apply = require('./apply')
exports.combine = require('./combine')
exports.sort = require('./sort')
exports.use = require('./use')
exports.scale = require('./scale')
exports.space = require('./space')
exports.layout = require('./layout')
exports.transform = require('./transform')
exports.plot = require('./plot')
exports.connector = require('./connector')

exports.define = (selector, width, height, driver) ->
  throw new Error("bad size: #{width} x #{height}") unless width and height
  return new FacetVis(selector, width, height, driver)
