express = require('express')
app = express()

app.get('/hello.txt', (req, res) ->
  res.send('Hello World')
)

console.log(__dirname)

app.use(express.static(__dirname + '/../static'))
app.use(express.static(__dirname + '/../target'))

app.listen(9876)
console.log('Listening on port 9876')

