mysql = require('mysql')

module.exports = ({host, user, password, database}) ->
  connection = mysql.createConnection({
    host
    user
    password
    database
  })

  connection.connect()
  return (sqlQuery, callback) ->
    connection.query(sqlQuery, callback)
    return