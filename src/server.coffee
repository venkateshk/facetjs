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
  user: 'root'
  password: 'root'
  database: 'facet'
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
druidPass = druidRequester({
  host: '10.60.134.138'
  port: 8080
  path: '/druid/v2/'
})
app.post '/pass/druid', (req, res) ->
  { context, query } = req.body
  druidPass(query, respondWithResult(res))
  return

app.post '/driver/druid', (req, res) ->
  { context, query } = req.body
  druidDriver({
    requester: druidPass
    dataSource: context.dataSource
    interval: context.interval.map((d) -> new Date(d))
    filters: null
  })(query, respondWithResult(res))
  return

# Druid notes:
# http://10.60.134.138:8080/druid/v2/datasources/
# http://10.60.134.138:8080/druid/v2/datasources/wikipedia_editstream
# http://10.60.134.138:8080/druid/v2/datasources/wikipedia_editstream/dimensions

app.listen(9876)
console.log('Listening on port 9876')

