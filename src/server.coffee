express = require('express')

{FacetQuery} = require('./query')

druidRequester = require('./requester/druidRequester')
sqlRequester = require('./requester/mySqlRequester')

simpleDriver = require('./driver/simpleDriver')
druidDriver = require('./driver/druidDriver')
sqlDriver = require('./driver/sqlDriver')

data = {}
data.diamonds = require('../data/diamonds.js')


app = express()

app.disable('x-powered-by')

app.use(express.compress())
app.use(express.json())

app.use(express.directory(__dirname + '/../static'))
app.use(express.static(__dirname + '/../static'))
app.use(express.static(__dirname + '/../build'))
app.use(express.static(__dirname + '/../data'))

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
  {context, query} = req.body
  try
    query = new FacetQuery(query)
  catch e
    res.send(501, "Bad query: #{e.message}")
    return

  simpleDriver(data[context.data])({context, query}, respondWithResult(res))
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
  sqlPass({context, query}, respondWithResult(res))
  return

app.post '/driver/sql', (req, res) ->
  {context, query} = req.body
  try
    query = new FacetQuery(query)
  catch e
    res.send(501, "Bad query: #{e.message}")
    return

  sqlDriver({
    requester: sqlPass
    table: context.table
  })({context, query}, respondWithResult(res))
  return

# Druid
app.post '/pass/druid', (req, res) ->
  {context, query} = req.body

  {host, port} = context or {}
  druidPass = druidRequester({
    host: host or '10.209.98.48'
    port: port or 8080
  })

  druidPass({context, query}, respondWithResult(res))
  return

app.post '/driver/druid', (req, res) ->
  { context, query } = req.body
  try
    query = new FacetQuery(query)
  catch e
    res.send(501, "Bad query: #{e.message}")
    return

  { host, port } = context or {}
  druidPass = druidRequester({
    host: host or '10.209.98.48'
    port: port or 8080
  })

  druidDriver({
    requester: druidPass
    dataSource: context.dataSource
  })({context, query}, respondWithResult(res))
  return

# Druid notes:
# http://10.209.98.48:8080/druid/v2/datasources/
# http://10.209.98.48:8080/druid/v2/datasources/wikipedia_editstream
# http://10.209.98.48:8080/druid/v2/datasources/wikipedia_editstream/dimensions

app.listen(9876)
console.log('Listening on port 9876')

