express = require('express')

druidRequester = require('./druidRequester')
sqlRequester = require('./mySqlRequester')

simpleDriver = require('./simpleDriver')
druidDriver = require('./druidDriver')
sqlDriver = require('./sqlDriver')

data = {}
data.diamonds = require('../data/diamonds.js')


app = express()

app.disable('x-powered-by')

app.use(express.compress())
app.use(express.json())

app.use(express.directory(__dirname + '/../static'))
app.use(express.static(__dirname + '/../static'))
app.use(express.static(__dirname + '/../target'))

app.get '/', (req, res) ->
  res.send('Welcome to facet')
  return

respondWithResult = (res) -> (err, result) ->
  if err
    res.json(500, err)
    return
  res.json(result)
  return

# Simple
app.post '/driver/simple', (req, res) ->
  { context, query } = req.body
  simpleDriver(data[context.data])(query, respondWithResult(res))
  return

# SQL
sqlPass = sqlRequester({
  host: 'localhost'
  database: 'facet'
  user: 'facet_user'
  password: 'HadleyWickham'
})
app.post '/pass/sql', (req, res) ->
  { context, query } = req.body
  sqlPass(query, respondWithResult(res))
  return

app.post '/driver/sql', (req, res) ->
  { context, query } = req.body
  sqlDriver({
    requester: sqlPass
    table: context.table
    filters: null
  })(query, respondWithResult(res))
  return

# Druid
app.post '/pass/druid', (req, res) ->
  { context, query } = req.body

  { host, port } = context or {}
  druidPass = druidRequester({
    host: host or '10.60.134.138'
    port: port or 8080
  })

  druidPass(query, respondWithResult(res))
  return

app.post '/driver/druid', (req, res) ->
  { context, query } = req.body

  { host, port } = context or {}
  druidPass = druidRequester({
    host: host or '10.60.134.138'
    port: port or 8080
  })

  druidDriver({
    requester: druidPass
    dataSource: context.dataSource
    filters: null
  })(query, respondWithResult(res))
  return

# Druid notes:
# http://10.60.134.138:8080/druid/v2/datasources/
# http://10.60.134.138:8080/druid/v2/datasources/wikipedia_editstream
# http://10.60.134.138:8080/druid/v2/datasources/wikipedia_editstream/dimensions

app.listen(9876)
console.log('Listening on port 9876')

