mysql = require('mysql')

module.exports = ({host, user, password, database}) ->
  connection = mysql.createConnection({
    host
    user
    password
    database
  })

  connection.connect()
  return ({context, query}, callback) ->
    connection.query(query, callback)
    return
