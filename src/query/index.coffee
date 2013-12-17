copyHere = (subModule) ->
  exports[k] = v for k, v of subModule
  return

copyHere(require('./filter'))
copyHere(require('./segmentFilter'))
copyHere(require('./dataset'))
copyHere(require('./split'))
copyHere(require('./apply'))
copyHere(require('./sort'))
copyHere(require('./combine'))
copyHere(require('./query'))
