utils = require('../utils')

druidRequester = require('../../druidRequester')
sqlRequester = require('../../mySqlRequester')

simpleDriver = require('../../simpleDriver')
sqlDriver = require('../../sqlDriver')
druidDriver = require('../../druidDriver')

# Set up drivers
driverFns = {}
verbose = false

# Simple
# diamondsData = require('../../../data/diamonds.js')
# driverFns.simple = simpleDriver(diamondsData)

# MySQL
sqlPass = sqlRequester({
  host: 'localhost'
  database: 'facet'
  user: 'facet_user'
  password: 'HadleyWickham'
})

sqlPass = utils.wrapVerbose(sqlPass, 'MySQL') if verbose

driverFns.mySql = sqlDriver({
  requester: sqlPass
  table: 'wiki_day_agg'
  filters: null
})

# # Druid
druidPass = druidRequester({
  host: '10.60.134.138'
  port: 8080
})

druidPass = utils.wrapVerbose(druidPass, 'Druid') if verbose

driverFns.druid = druidDriver({
  requester: druidPass
  dataSource: 'wikipedia_editstream'
  timeAttribute: 'time'
  approximate: true
  filter: {
    type: 'within'
    attribute: 'time'
    range: [
      new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0))
      new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))
    ]
  }
})

testEquality = utils.makeEqualityTest(driverFns)


exports["apply count"] = testEquality {
  drivers: ['mySql', 'druid']
  query: [
    { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
    { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
  ]
}

exports["filter; apply count"] = testEquality {
  drivers: ['mySql', 'druid']
  query: [
    { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
    { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
    { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
  ]
}

exports["apply arithmetic"] = testEquality {
  drivers: ['mySql', 'druid']
  query: [
    { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
    {
      operation: 'apply'
      name: 'Added + Deleted'
      arithmetic: 'add'
      operands: [
        { aggregate: 'sum', attribute: 'added' }
        { aggregate: 'sum', attribute: 'deleted' }
      ]
    }
    {
      operation: 'apply'
      name: 'Added - Deleted'
      arithmetic: 'subtract'
      operands: [
        { aggregate: 'sum', attribute: 'added' }
        { aggregate: 'sum', attribute: 'deleted' }
      ]
    }
    { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
  ]
}

exports["split time; combine time"] = testEquality {
  drivers: ['mySql', 'druid']
  query: [
    { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
    { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
  ]
}

# The sorting here still does not match - ask FJ
# exports["split page; combine page"] = testEquality {
#   drivers: ['mySql', 'druid']
#   query: [
#     { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page' }
#     { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Page', direction: 'descending' }, limit: 7 }
#   ]
# }

exports["split time; apply count"] = testEquality {
  drivers: ['mySql', 'druid']
  query: [
    { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
    { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
    { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
    { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
  ]
}

exports["split time; apply count; sort Count descending"] = testEquality {
  drivers: ['mySql', 'druid']
  query: [
    { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
    { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
    { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 3 }
  ]
}

exports["split time; apply count; sort Count ascending"] = testEquality {
  drivers: ['mySql', 'druid']
  query: [
    { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
    { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
    { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'ascending' }, limit: 3 }
  ]
}

# ToDo: Test timezone support

exports["split page; apply count; sort count descending"] = testEquality {
  drivers: ['mySql', 'druid']
  query: [
    { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page' }
    { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
    { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
    { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }
  ]
}

exports["split language; apply count; sort count descending > split page; apply count; sort count descending"] = testEquality {
  drivers: ['mySql', 'druid']
  query: [
    { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
    { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
    { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
    { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 3 }

    { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page' }
    { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
    { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
    { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 3 }
  ]
}

exports["split page; apply count; sort count ascending"] = testEquality {
  drivers: ['mySql', 'druid']
  query: [
    { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page' }
    { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
    { operation: 'apply', name: 'Deleted', aggregate: 'sum', attribute: 'deleted' }
    { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Deleted', direction: 'ascending' }, limit: 5 }
  ]
}

exports["filter language=en; split page; apply count; sort deleted ascending"] = testEquality {
  drivers: ['mySql', 'druid']
  query: [
    { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
    { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page' }
    { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
    { operation: 'apply', name: 'Deleted', aggregate: 'sum', attribute: 'deleted' }
    { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Deleted', direction: 'ascending' }, limit: 5 }
  ]
}

exports["filter with nested ANDs"] = testEquality {
  drivers: ['mySql', 'druid']
  query: [
    {
      operation: "filter",
      type: "and"
      filters: [
        {
          type: "within"
          attribute: "time"
          range: [
            new Date(Date.UTC(2013, 2-1, 26, 10, 0, 0))
            new Date(Date.UTC(2013, 2-1, 27, 15, 0, 0))
          ]
        }
        {
          type: "and",
          filters: [
            { type: "is", attribute: "robot", value: "0" }
            { type: "is", attribute: "namespace", value: "article" }
            { type: "is", attribute: "language", value: "en" }
          ]
        }
      ]
    },
    { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
  ]
}

# Should work once druid with advanced JS aggregate is deployed
exports["apply sum(count, robot=0), sum(added, robot=1)"] = testEquality {
  drivers: ['mySql', 'druid']
  query: [
    {
      operation: "apply"
      name: "Count R=0"
      aggregate: "sum", attribute: "count"
      filter: { type: 'is', attribute: "robot", value: "0" }
    }
    {
      operation: "apply"
      name: "Added R=1"
      aggregate: "sum", attribute: "added"
      filter: { type: 'is', attribute: "robot", value: "1" }
    }
    {
      operation: "apply"
      name: "Min Added R=1"
      aggregate: "min", attribute: "added"
      filter: { type: 'is', attribute: "robot", value: "1" }
    }
    {
      operation: "apply"
      name: "Max Added R=1"
      aggregate: "max", attribute: "added"
      filter: { type: 'is', attribute: "robot", value: "1" }
    }
    {
      operation: "apply"
      name: "CountComplexFilter"
      aggregate: "sum", attribute: "count"
      filter: {
        type: 'and'
        filters: [
          { type: 'is', attribute: "robot", value: "1" }
          { type: 'in', attribute: "language", values: ["en", "fr"] }
        ]
      }
    }
  ]
}

exports["split page; apply sum(count, robot=0), sum(added, robot=1)"] = testEquality {
  drivers: ['mySql', 'druid']
  query: [
    {
      operation: "split"
      name: 'Page', bucket: 'identity', attribute: 'page'
    }
    {
      operation: "apply"
      name: "Count R=0"
      aggregate: "sum", attribute: "count"
      filter: { type: 'is', attribute: "robot", value: "0" }
    }
    {
      operation: "apply"
      name: "Added R=1"
      aggregate: "sum", attribute: "added"
      filter: { type: 'is', attribute: "robot", value: "1" }
    }
    {
      operation: 'combine', combine: 'slice'
      sort: { compare: 'natural', prop: 'Count R=0', direction: 'descending' }
      limit: 5
    }
  ]
}
