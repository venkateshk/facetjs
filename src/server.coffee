express = require('express')
simpleDriver = require('./simple.js')


data = {}
data.data1 = do ->
  pick = (arr) -> arr[Math.floor(Math.random() * arr.length)]
  now = Date.now()
  w = 100
  ret = []
  for i in [0...400]
    ret.push {
      id: i
      time: new Date(now + i * 13 * 1000)
      letter: 'ABC'[Math.floor(3 * i / 400)]
      number: pick([1, 10, 3, 4])
      scoreA: i * Math.random() * Math.random()
      scoreB: 10 * Math.random()
      walk: w += Math.random() - 0.5 + 0.02
    }
  return ret


app = express()

app.disable('x-powered-by')

app.use(express.compress())
app.use(express.json())

app.use(express.static(__dirname + '/../static'))
app.use(express.static(__dirname + '/../target'))

app.get('/', (req, res) ->
  res.send('Welcome to facet')
)


app.post '/driver/simple', (req, res) ->
  { context, query } = req.body
  simpleDriver(data[context.data])(query, (err, result) ->
    if err
      res.json(500, err)
      return

    res.json(result)
  )
  return


app.post '/driver/sql', (req, res) ->

  return


app.post '/driver/druid', (req, res) ->

  return


app.post '/pass/sql', (req, res) ->

  return


app.post '/pass/druid', (req, res) ->

  return


app.listen(9876)
console.log('Listening on port 9876')

