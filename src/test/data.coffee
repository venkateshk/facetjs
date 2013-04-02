exports.diamond = {}
exports.diamond['1'] = {}
exports.diamond['2'] = {}

exports.diamond['1'].query = [
  { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut' }
  { operation: 'apply', name: 'Count', aggregate: 'count' }
  { operation: 'combine', sort: { prop: 'Cut', compare: 'natural', direction: 'descending' } }
]

exports.diamond['1'].data = {
  prop: { Count: 21 }
  splits: [
    { prop: { Cut: 'A', Count: 1 } }
    { prop: { Cut: 'B', Count: 2 } }
    { prop: { Cut: 'C', Count: 3 } }
    { prop: { Cut: 'D', Count: 4 } }
    { prop: { Cut: 'E', Count: 5 } }
    { prop: { Cut: 'F"', Count: 6 } }
  ]
}

exports.diamond['2'].query = [
  { operation: 'split', name: 'Carat', bucket: 'continuous', size: 0.1, offset: 0.005, attribute: 'carat' }
  { operation: 'apply', name: 'Count', aggregate: 'count' }
  { operation: 'combine', sort: { prop: 'Count', compare: 'natural', direction: 'descending' }, limit: 5 }
  { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut' }
  { operation: 'apply', name: 'Count', aggregate: 'count' }
  { operation: 'combine', sort: { prop: 'Cut', compare: 'natural', direction: 'descending' } }
]
exports.diamond['2'].data = {
  "prop": {},
  "splits": [
    {
      "prop": {
        "Carat": [
          0.295,
          0.395
        ],
        "Count": 11493
      },
      "splits": [
        {
          "prop": {
            "Cut": "Very Good",
            "Count": 1885
          }
        },
        {
          "prop": {
            "Cut": "Premium",
            "Count": 2745
          }
        },
        {
          "prop": {
            "Cut": "Ideal",
            "Count": 6117
          }
        },
        {
          "prop": {
            "Cut": "Good",
            "Count": 694
          }
        },
        {
          "prop": {
            "Cut": "Fair",
            "Count": 52
          }
        }
      ]
    },
    {
      "prop": {
        "Carat": [
          0.995,
          1.095
        ],
        "Count": 7290
      },
      "splits": [
        {
          "prop": {
            "Cut": "Very Good",
            "Count": 1771
          }
        },
        {
          "prop": {
            "Cut": "Premium",
            "Count": 2121
          }
        },
        {
          "prop": {
            "Cut": "Ideal",
            "Count": 2057
          }
        },
        {
          "prop": {
            "Cut": "Good",
            "Count": 965
          }
        },
        {
          "prop": {
            "Cut": "Fair",
            "Count": 376
          }
        }
      ]
    },
    {
      "prop": {
        "Carat": [
          0.495,
          0.595
        ],
        "Count": 6546
      },
      "splits": [
        {
          "prop": {
            "Cut": "Very Good",
            "Count": 1349
          }
        },
        {
          "prop": {
            "Cut": "Premium",
            "Count": 1207
          }
        },
        {
          "prop": {
            "Cut": "Ideal",
            "Count": 3348
          }
        },
        {
          "prop": {
            "Cut": "Good",
            "Count": 509
          }
        },
        {
          "prop": {
            "Cut": "Fair",
            "Count": 133
          }
        }
      ]
    },
    {
      "prop": {
        "Carat": [
          0.695,
          0.795
        ],
        "Count": 5946
      },
      "splits": [
        {
          "prop": {
            "Cut": "Very Good",
            "Count": 1579
          }
        },
        {
          "prop": {
            "Cut": "Premium",
            "Count": 1258
          }
        },
        {
          "prop": {
            "Cut": "Ideal",
            "Count": 2255
          }
        },
        {
          "prop": {
            "Cut": "Good",
            "Count": 593
          }
        },
        {
          "prop": {
            "Cut": "Fair",
            "Count": 261
          }
        }
      ]
    },
    {
      "prop": {
        "Carat": [
          0.395,
          0.495
        ],
        "Count": 4582
      },
      "splits": [
        {
          "prop": {
            "Cut": "Very Good",
            "Count": 869
          }
        },
        {
          "prop": {
            "Cut": "Premium",
            "Count": 1141
          }
        },
        {
          "prop": {
            "Cut": "Ideal",
            "Count": 2112
          }
        },
        {
          "prop": {
            "Cut": "Good",
            "Count": 407
          }
        },
        {
          "prop": {
            "Cut": "Fair",
            "Count": 53
          }
        }
      ]
    }
  ]
}

exports.diamond['2'].tabular = [
  { Carat: [ 0.295, 0.395 ], Count: 1885, Cut: 'Very Good' }
  { Carat: [ 0.295, 0.395 ], Count: 2745, Cut: 'Premium' }
  { Carat: [ 0.295, 0.395 ], Count: 6117, Cut: 'Ideal' }
  { Carat: [ 0.295, 0.395 ], Count: 694, Cut: 'Good' }
  { Carat: [ 0.295, 0.395 ], Count: 52, Cut: 'Fair' }
  { Carat: [ 0.995, 1.095 ], Count: 1771, Cut: 'Very Good' }
  { Carat: [ 0.995, 1.095 ], Count: 2121, Cut: 'Premium' }
  { Carat: [ 0.995, 1.095 ], Count: 2057, Cut: 'Ideal' }
  { Carat: [ 0.995, 1.095 ], Count: 965, Cut: 'Good' }
  { Carat: [ 0.995, 1.095 ], Count: 376, Cut: 'Fair' }
  { Carat: [ 0.495, 0.595 ], Count: 1349, Cut: 'Very Good' }
  { Carat: [ 0.495, 0.595 ], Count: 1207, Cut: 'Premium' }
  { Carat: [ 0.495, 0.595 ], Count: 3348, Cut: 'Ideal' }
  { Carat: [ 0.495, 0.595 ], Count: 509, Cut: 'Good' }
  { Carat: [ 0.495, 0.595 ], Count: 133, Cut: 'Fair' }
  { Carat: [ 0.695, 0.795 ], Count: 1579, Cut: 'Very Good' }
  { Carat: [ 0.695, 0.795 ], Count: 1258, Cut: 'Premium' }
  { Carat: [ 0.695, 0.795 ], Count: 2255, Cut: 'Ideal' }
  { Carat: [ 0.695, 0.795 ], Count: 593, Cut: 'Good' }
  { Carat: [ 0.695, 0.795 ], Count: 261, Cut: 'Fair' }
  { Carat: [ 0.395, 0.495 ], Count: 869, Cut: 'Very Good' }
  { Carat: [ 0.395, 0.495 ], Count: 1141, Cut: 'Premium' }
  { Carat: [ 0.395, 0.495 ], Count: 2112, Cut: 'Ideal' }
  { Carat: [ 0.395, 0.495 ], Count: 407, Cut: 'Good' }
  { Carat: [ 0.395, 0.495 ], Count: 53, Cut: 'Fair' }
]

exports.diamond['2'].csv = '"Carat","Cut","Count"\r\n"0.295-0.395","Very Good","1885"\r\n"0.295-0.395","Premium","2745"\r\n"0.295-0.395","Ideal","6117"\r\n"0.295-0.395","Good","694"\r\n"0.295-0.395","Fair","52"\r\n"0.995-1.095","Very Good","1771"\r\n"0.995-1.095","Premium","2121"\r\n"0.995-1.095","Ideal","2057"\r\n"0.995-1.095","Good","965"\r\n"0.995-1.095","Fair","376"\r\n"0.495-0.595","Very Good","1349"\r\n"0.495-0.595","Premium","1207"\r\n"0.495-0.595","Ideal","3348"\r\n"0.495-0.595","Good","509"\r\n"0.495-0.595","Fair","133"\r\n"0.695-0.795","Very Good","1579"\r\n"0.695-0.795","Premium","1258"\r\n"0.695-0.795","Ideal","2255"\r\n"0.695-0.795","Good","593"\r\n"0.695-0.795","Fair","261"\r\n"0.395-0.495","Very Good","869"\r\n"0.395-0.495","Premium","1141"\r\n"0.395-0.495","Ideal","2112"\r\n"0.395-0.495","Good","407"\r\n"0.395-0.495","Fair","53"'
