mysql = require('mysql')

module.exports = ({locator, user, password, database}) ->
  return ({context, query}, callback) ->
    locator (err, location) ->
      if err
        callback(err)
        return

      connection = mysql.createConnection({
        host: location.host
        port: location.port ? 3306
        user
        password
        database
        charset: 'UTF8_BIN'
      })

      connection.connect()
      connection.query(query, callback)
      connection.end()
      return

    return
