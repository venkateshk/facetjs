{ expect } = require("chai")
utils = require('../../test/utils')

{ simpleLocator } = require('../../build/locator/simpleLocator')

{ hadoopRequester } = require('../../build/requester/hadoopRequester')

prodHadoopRequester = hadoopRequester({
  locator: simpleLocator('10.151.42.82')
})

describe "Hadoop requester", ->
  @timeout(20 * 60 * 1000)

  testQuery = {
    "datasets": [
      {
        "name": "ideal-cut",
        "path": "s3://metamx-user-scratch/gian/diamonds",
        "intervals": [
          "2000-01-01/PT1H"
        ],
        "filter": "function(datum) { return datum['cut'] === 'Ideal'; }"
      },
      {
        "name": "good-cut",
        "path": "s3://metamx-user-scratch/gian/diamonds",
        "intervals": [
          "2000-01-01/PT1H"
        ],
        "filter": "function(datum) { return datum['cut'] === 'Good'; }"
      }
    ],
    "split": {
      "name": "Clarity",
      "fn": "function(t) { return t.datum['clarity']; }"
    },
    "applies": "function(iter) {\n  var t, x, datum, dataset, seen = {};\n  \n  var prop = {\n    '_B1__S1_PriceDiff': 0,\n    '_B2__S1_PriceDiff': 0,\n    '_B1__S2_PriceDiff': 0,\n    '_B2__S2_PriceDiff': 0\n  }\n  while(iter.hasNext()) {\n    t = iter.next();\n    datum = t.datum; dataset = t.dataset;\n    if(dataset === 'ideal-cut') {;\n      x = datum['price'];\n      prop['_B1__S1_PriceDiff'] += Number(x);\n      prop['_B2__S1_PriceDiff']++;\n    };\n    if(dataset === 'good-cut') {;\n      x = datum['price'];\n      prop['_B1__S2_PriceDiff'] += Number(x);\n      prop['_B2__S2_PriceDiff']++;\n    }\n  }\n  prop['_S1_PriceDiff'] = (prop['_B1__S1_PriceDiff'] / prop['_B2__S1_PriceDiff']);\n  prop['PriceDiff'] = (prop['_S1_PriceDiff'] - prop['_S2_PriceDiff']);\n  prop['_S2_PriceDiff'] = (prop['_B1__S2_PriceDiff'] / prop['_B2__S2_PriceDiff']);\n  prop['PriceDiff'] = (prop['_S1_PriceDiff'] - prop['_S2_PriceDiff'])\n  return prop;\n}",
    "combine": {
      "comparator": "function(b, a) { return a['PriceDiff'] < b['PriceDiff'] ? -1 : a['PriceDiff'] > b['PriceDiff'] ? 1 : a['PriceDiff'] >= b['PriceDiff'] ? 0 : NaN; }",
      "limit": 4
    }
  }

  expectedResults = [
    {
      _B1__S1_PriceDiff: 633016,
      _B2__S1_PriceDiff: 146,
      _B1__S2_PriceDiff: 345277,
      _B2__S2_PriceDiff: 96,
      _S1_PriceDiff: 4335.726027397261,
      PriceDiff: 739.0906107305941,
      _S2_PriceDiff: 3596.6354166666665,
      Clarity: 'I1'
    }
    {
      _B1__S1_PriceDiff: 5052261,
      _B2__S1_PriceDiff: 2047,
      _B1__S2_PriceDiff: 419388,
      _B2__S2_PriceDiff: 186,
      _S1_PriceDiff: 2468.1294577430385,
      PriceDiff: 213.35526419465123,
      _S2_PriceDiff: 2254.7741935483873,
      Clarity: 'VVS1'
    }
    {
      _B1__S1_PriceDiff: 12355965,
      _B2__S1_PriceDiff: 2598,
      _B1__S2_PriceDiff: 4951262,
      _B2__S2_PriceDiff: 1081,
      _S1_PriceDiff: 4755.952655889146,
      PriceDiff: 175.69178632392868,
      _S2_PriceDiff: 4580.260869565217,
      Clarity: 'SI2'
    }
    {
      _B1__S1_PriceDiff: 8470256,
      _B2__S1_PriceDiff: 2606,
      _B1__S2_PriceDiff: 880625,
      _B2__S2_PriceDiff: 286,
      _S1_PriceDiff: 3250.290099769762,
      PriceDiff: 171.18170816137035,
      _S2_PriceDiff: 3079.1083916083917,
      Clarity: 'VVS2'
    }
  ]

  it.skip "does a query", (done) ->
    prodHadoopRequester {
      context: {}
      query: testQuery
    }, (err, results) ->
      console.log err
      expect(err).to.be.null
      expect(results).to.deep.equal(expectedResults)
      done()



