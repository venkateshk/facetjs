utils = require('../utils')

druidRequester = require('../../druidRequester')
sqlRequester = require('../../mySqlRequester')

simpleDriver = require('../../simpleDriver')
sqlDriver = require('../../sqlDriver')
druidDriver = require('../../druidDriver')

# Set up drivers
driverFns = {}

# Simple
diamondsData = require('../../../data/diamonds.js')
driverFns.simple = simpleDriver(diamondsData)

# MySQL
sqlPass = sqlRequester({
  host: 'localhost'
  database: 'facet'
  user: 'facet_user'
  password: 'HadleyWickham'
})

driverFns.mySql = sqlDriver({
  requester: sqlPass
  table: 'diamonds'
  filters: null
})

# # Druid
# druidPass = druidRequester({
#   host: '10.60.134.138'
#   port: 8080
# })

# driverFns.druid = druidDriver({
#   requester: druidPass
#   dataSource: context.dataSource
#   filter: null
# })

testDrivers = utils.makeDriverTest(driverFns)


# Tests

exports["apply count"] = testDrivers {
  drivers: ['simple', 'mySql']
  query: [
    { operation: 'apply', name: 'Count',  aggregate: 'count' }
  ]
}

exports["many applies"] = testDrivers {
  drivers: ['simple', 'mySql']
  query: [
    { operation: 'apply', name: 'Constant 42',  aggregate: 'constant', value: '42' }
    { operation: 'apply', name: 'Count',  aggregate: 'count' }
    { operation: 'apply', name: 'Total Price',  aggregate: 'sum', attribute: 'price' }
    { operation: 'apply', name: 'Avg Price',  aggregate: 'average', attribute: 'price' }
    { operation: 'apply', name: 'Min Price',  aggregate: 'min', attribute: 'price' }
    { operation: 'apply', name: 'Max Price',  aggregate: 'max', attribute: 'price' }
    { operation: 'apply', name: 'Num Cuts',  aggregate: 'uniqueCount', attribute: 'cut' }
  ]
}

exports["filter applies"] = testDrivers {
  drivers: ['simple', 'mySql']
  query: [
    {
      operation: 'apply', name: 'Constant 42',  aggregate: 'constant', value: '42',
      filter: { attribute: 'color', type: 'is', value: 'E' }
    }
    {
      operation: 'apply', name: 'Count',  aggregate: 'count',
      filter: { attribute: 'color', type: 'is', value: 'E' }
    }
    {
      operation: 'apply', name: 'Total Price',  aggregate: 'sum', attribute: 'price',
      filter: { attribute: 'color', type: 'is', value: 'E' }
    }
    {
      operation: 'apply', name: 'Avg Price',  aggregate: 'average', attribute: 'price',
      filter: { attribute: 'color', type: 'is', value: 'E' }
    }
    {
      operation: 'apply', name: 'Min Price',  aggregate: 'min', attribute: 'price',
      filter: { attribute: 'color', type: 'is', value: 'E' }
    }
    {
      operation: 'apply', name: 'Max Price',  aggregate: 'max', attribute: 'price',
      filter: { attribute: 'color', type: 'is', value: 'E' }
    }
    {
      operation: 'apply', name: 'Num Cuts',  aggregate: 'uniqueCount', attribute: 'cut',
      filter: { attribute: 'color', type: 'is', value: 'E' }
    }
  ]
}

exports["split cut; no apply"] = testDrivers {
  drivers: ['simple', 'mySql']
  query: [
    { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut' }
    { operation: 'combine', combine: 'slice', sort: { prop: 'Cut', compare: 'natural', direction: 'descending' } }
  ]
}

exports["split cut; apply count"] = testDrivers {
  drivers: ['simple', 'mySql']
  query: [
    { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut' }
    { operation: 'apply', name: 'Count', aggregate: 'count' }
    { operation: 'combine', combine: 'slice', sort: { prop: 'Cut', compare: 'natural', direction: 'descending' } }
  ]
}

exports["split carat; apply count"] = testDrivers {
  drivers: ['simple', 'mySql']
  query: [
    { operation: 'split', name: 'Carat', bucket: 'continuous', size: 0.1, offset: 0.005, attribute: 'carat' }
    { operation: 'apply', name: 'Count', aggregate: 'count' }
    { operation: 'combine', combine: 'slice', sort: { prop: 'Carat', compare: 'natural', direction: 'ascending' } }
  ]
}

exports["split cut; apply count > split carat; apply count"] = testDrivers {
  drivers: ['simple', 'mySql']
  query: [
    { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut' }
    { operation: 'apply', name: 'Count', aggregate: 'count' }
    { operation: 'combine', combine: 'slice', sort: { prop: 'Cut', compare: 'natural', direction: 'descending' } }

    { operation: 'split', name: 'Carat', bucket: 'continuous', size: 0.1, offset: 0.005, attribute: 'carat' }
    { operation: 'apply', name: 'Count', aggregate: 'count' }
    { operation: 'combine', combine: 'slice', sort: { prop: 'Carat', compare: 'natural', direction: 'descending' } }
  ]
}

exports["split(1, .5) carat; apply count > split cut; apply count"] = testDrivers {
  drivers: ['simple', 'mySql']
  query: [
    { operation: 'split', name: 'Carat', bucket: 'continuous', size: 1, offset: 0.5, attribute: 'carat' }
    { operation: 'apply', name: 'Count', aggregate: 'count' }
    { operation: 'combine', combine: 'slice', sort: { prop: 'Count', compare: 'natural', direction: 'descending' }, limit: 5 }

    { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut' }
    { operation: 'apply', name: 'Count', aggregate: 'count' }
    { operation: 'combine', combine: 'slice', sort: { prop: 'Cut', compare: 'natural', direction: 'descending' } }
  ]
}

exports["split carat; apply count > split cut; apply count"] = testDrivers {
  drivers: ['simple', 'mySql']
  query: [
    { operation: 'split', name: 'Carat', bucket: 'continuous', size: 0.1, offset: 0.005, attribute: 'carat' }
    { operation: 'apply', name: 'Count', aggregate: 'count' }
    { operation: 'combine', combine: 'slice', sort: { prop: 'Count', compare: 'natural', direction: 'descending' }, limit: 5 }

    { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut' }
    { operation: 'apply', name: 'Count', aggregate: 'count' }
    { operation: 'combine', combine: 'slice', sort: { prop: 'Cut', compare: 'natural', direction: 'descending' } }
  ]
}

exports["apply arithmetic"] = testDrivers {
  drivers: ['simple', 'mySql']
  query: [
    {
      operation: 'apply'
      name: 'Count Plus One'
      arithmetic: 'add'
      operands: [
        { aggregate: 'count' }
        { aggregate: 'constant', value: 1 }
      ]
    }
    {
      operation: 'apply'
      name: 'Price + Carat'
      arithmetic: 'add'
      operands: [
        { aggregate: 'sum', attribute: 'price' }
        { aggregate: 'sum', attribute: 'carat' }
      ]
    }
    {
      operation: 'apply'
      name: 'Price - Carat'
      arithmetic: 'subtract'
      operands: [
        { aggregate: 'sum', attribute: 'price' }
        { aggregate: 'sum', attribute: 'carat' }
      ]
    }
    {
      operation: 'apply'
      name: 'Price * Carat'
      arithmetic: 'multiply'
      operands: [
        { aggregate: 'min', attribute: 'price' }
        { aggregate: 'max', attribute: 'carat' }
      ]
    }
    {
      operation: 'apply'
      name: 'Price / Carat'
      arithmetic: 'divide'
      operands: [
        { aggregate: 'sum', attribute: 'price' }
        { aggregate: 'sum', attribute: 'carat' }
      ]
    }
  ]
}

exports["apply arithmetic"] = testDrivers {
  drivers: ['simple', 'mySql']
  query: [
    {
      operation: 'apply'
      name: 'Count Plus One'
      arithmetic: 'add'
      operands: [
        { aggregate: 'count' }
        { aggregate: 'constant', value: 1 }
      ]
    }
  ]
}

exports["is filter"] = testDrivers {
  drivers: ['simple', 'mySql']
  query: [
    { operation: 'filter', type: 'is', attribute: 'color', value: 'E' }
    { operation: 'apply', name: 'Count', aggregate: 'count' }
  ]
}


exports["complex filter"] = testDrivers {
  drivers: ['simple', 'mySql']
  query: [
    {
      operation: 'filter'
      type: 'or'
      filters: [
        { type: 'is', attribute: 'color', value: 'E' }
        {
          type: 'and'
          filters: [
            { type: 'in', attribute: 'clarity', values: ['SI1', 'SI2'] }
            { type: 'not', filter: { type: 'is', attribute: 'cut', value: 'Good' } }
          ]
        }
      ]
    }
    { operation: 'apply', name: 'Count', aggregate: 'count' }
  ]
}

exports["complex filter; split carat; apply count > split cut; apply count"] = testDrivers {
  drivers: ['simple', 'mySql']
  query: [
    {
      operation: 'filter'
      type: 'or'
      filters: [
        { type: 'is', attribute: 'color', value: 'E' }
        {
          type: 'and'
          filters: [
            { type: 'in', attribute: 'clarity', values: ['SI1', 'SI2'] }
            { type: 'not', filter: { type: 'is', attribute: 'cut', value: 'Good' } }
          ]
        }
      ]
    }
    { operation: 'apply', name: 'Count', aggregate: 'count' }

    { operation: 'split', name: 'Carat', bucket: 'continuous', size: 0.1, offset: 0.005, attribute: 'carat' }
    { operation: 'apply', name: 'Count', aggregate: 'count' }
    { operation: 'combine', combine: 'slice', sort: { prop: 'Count', compare: 'natural', direction: 'descending' }, limit: 5 }

    { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut' }
    { operation: 'apply', name: 'Count', aggregate: 'count' }
    { operation: 'combine', combine: 'slice', sort: { prop: 'Cut', compare: 'natural', direction: 'descending' } }
  ]
}
