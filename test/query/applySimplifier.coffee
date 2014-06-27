{expect} = require("chai")

{FacetApply, ApplySimplifier} = require('../../src/query')

getValueOf = (d) -> d.valueOf()

describe "ApplySimplifier", ->
  customPostProcessorScheme = {
    constant: ({value}) -> "CONSTANT(#{value})"
    getter: ({name}) -> "[#{name}]"
    arithmetic: (arithmetic, lhs, rhs) ->
      return switch arithmetic
        when 'add' then      "(#{lhs} + #{rhs})"
        when 'subtract' then "(#{lhs} - #{rhs})"
        when 'multiply' then "(#{lhs} * #{rhs})"
        when 'divide' then   "(#{lhs} / #{rhs})"
        else throw new Error('unknown arithmetic')
    finish: (name, getter) -> "#{name} <- #{getter}"
  }

  describe "single dataset", ->
    it "works on basic example (leave constant)", ->
      applySpecs = [
        { name: 'Count', aggregate: 'sum', attribute: 'count' }
        { name: 'Const42', aggregate: 'constant', value: 42 }
      ]

      applySimplifier = new ApplySimplifier({
        postProcessorScheme: customPostProcessorScheme
        breakToSimple: true
        topLevelConstant: 'leave'
      })
      applySimplifier.addApplies(applySpecs.map(FacetApply.fromSpec))

      expect(applySimplifier.getSimpleApplies().map(getValueOf)).to.deep.equal(
        applySpecs
      )
      expect(applySimplifier.getPostProcessors()).to.deep.equal([])

    it "works on basic example (process constant)", ->
      applySpecs = [
        { name: 'Count', aggregate: 'sum', attribute: 'count' }
        { name: 'Const42', aggregate: 'constant', value: 42 }
      ]

      applySimplifier = new ApplySimplifier({
        postProcessorScheme: customPostProcessorScheme
        breakToSimple: true
        topLevelConstant: 'process'
      })
      applySimplifier.addApplies(applySpecs.map(FacetApply.fromSpec))

      expect(applySimplifier.getSimpleApplies().map(getValueOf)).to.deep.equal(
        applySpecs.slice(0, 1)
      )
      expect(applySimplifier.getPostProcessors()).to.deep.equal([
        "Const42 <- CONSTANT(42)"
      ])

    it "should break average", ->
      applySpecs = [
        { name: 'Avg Count', aggregate: 'average', attribute: 'count' }
      ]

      applySimplifier = new ApplySimplifier({
        postProcessorScheme: customPostProcessorScheme
        breakToSimple: true
        breakAverage: true
      })
      applySimplifier.addApplies(applySpecs.map(FacetApply.fromSpec))

      expect(applySimplifier.getSimpleApplies().map(getValueOf)).to.deep.equal([
        {
          name: "_S1_Avg Count",
          aggregate: "sum",
          attribute: "count"
        },
        {
          name: "_S2_Avg Count",
          aggregate: "count"
        }
      ])
      expect(applySimplifier.getPostProcessors()).to.deep.equal([
        "Avg Count <- ([_S1_Avg Count] / [_S2_Avg Count])"
      ])

    it "should break nested average", ->
      applySpecs = [
        {
          name: 'Avg Count By 100'
          arithmetic: "divide"
          operands: [
            { aggregate: 'average', attribute: 'count' },
            { aggregate: 'constant', value: 100 }
          ]
        }
      ]

      applySimplifier = new ApplySimplifier({
        postProcessorScheme: customPostProcessorScheme
        breakToSimple: true
        breakAverage: true
        topLevelConstant: 'leave'
      })
      applySimplifier.addApplies(applySpecs.map(FacetApply.fromSpec))

      expect(applySimplifier.getSimpleApplies().map(getValueOf)).to.deep.equal([
        {
          name: "_S1_Avg Count By 100"
          aggregate: "sum"
          attribute: "count"
        }
        {
          name: "_S2_Avg Count By 100"
          aggregate: "count"
        }
      ])
      expect(applySimplifier.getPostProcessors()).to.deep.equal([
        "Avg Count By 100 <- (([_S1_Avg Count By 100] / [_S2_Avg Count By 100]) / CONSTANT(100))"
      ])

    it "works prefers existing applies", ->
      applySpecs = [
        {
          name: 'Kills'
          aggregate: "sum",
          attribute: "kills"
        }
        {
          name: 'Deaths'
          aggregate: "sum"
          attribute: "deaths"
        }
        {
          name: 'K/D Ratio'
          arithmetic: "divide",
          operands: [
            {
              aggregate: "sum",
              attribute: "kills"
            },
            {
              aggregate: "sum"
              attribute: "deaths"
            }
          ]
        }
      ]

      applySimplifier = new ApplySimplifier({
        postProcessorScheme: customPostProcessorScheme
        breakToSimple: true
        topLevelConstant: 'process'
      })
      applySimplifier.addApplies(applySpecs.map(FacetApply.fromSpec))

      expect(applySimplifier.getSimpleApplies().map((d) -> d.valueOf())).to.deep.equal([
        {
          name: 'Kills'
          aggregate: "sum",
          attribute: "kills"
        }
        {
          name: 'Deaths'
          aggregate: "sum"
          attribute: "deaths"
        }
      ])
      expect(applySimplifier.getPostProcessors()).to.deep.equal([
        "K/D Ratio <- ([Kills] / [Deaths])"
      ])

    it "works prefers existing applies (with dataset)", ->
      applySpecs = [
        {
          name: 'Kills'
          dataset: 'mydata'
          aggregate: "sum",
          attribute: "kills"
        },
        {
          name: 'Deaths'
          dataset: 'mydata'
          aggregate: "sum"
          attribute: "deaths"
        }
        {
          name: 'K/D Ratio'
          dataset: 'mydata'
          arithmetic: "divide",
          operands: [
            {
              aggregate: "sum",
              attribute: "kills"
            },
            {
              aggregate: "sum"
              attribute: "deaths"
            }
          ]
        }
      ]

      applySimplifier = new ApplySimplifier({
        postProcessorScheme: customPostProcessorScheme
        breakToSimple: true
        topLevelConstant: 'process'
      })
      applySimplifier.addApplies(applySpecs.map(FacetApply.fromSpec))

      expect(applySimplifier.getSimpleApplies().map((d) -> d.valueOf())).to.deep.equal([
        {
          name: 'Kills'
          dataset: 'mydata'
          aggregate: "sum",
          attribute: "kills"
        }
        {
          name: 'Deaths'
          dataset: 'mydata'
          aggregate: "sum"
          attribute: "deaths"
        }
      ])
      expect(applySimplifier.getPostProcessors()).to.deep.equal([
        "K/D Ratio <- ([Kills] / [Deaths])"
      ])

    it "splits up a nested formula", ->
      applySpecs = [
        {
          name: "K/D percent",
          arithmetic: "multiply",
          operands: [
            {
              arithmetic: "divide",
              operands: [
                {
                  aggregate: "sum",
                  attribute: "kills"
                },
                {
                  aggregate: "sum",
                  attribute: "death"
                }
              ]
            },
            {
              aggregate: "constant",
              value: 100
            }
          ]
        }
      ]

      applySimplifier = new ApplySimplifier({
        postProcessorScheme: customPostProcessorScheme
        breakToSimple: true
        topLevelConstant: 'leave'
      })
      applySimplifier.addApplies(applySpecs.map(FacetApply.fromSpec))

      expect(applySimplifier.getSimpleApplies().map((d) -> d.valueOf())).to.deep.equal([
        {
          name: "_S1_K/D percent",
          aggregate: "sum",
          attribute: "kills"
        },
        {
          name: "_S2_K/D percent",
          aggregate: "sum",
          attribute: "death"
        }
      ])
      expect(applySimplifier.getPostProcessors()).to.deep.equal([
        "K/D percent <- (([_S1_K/D percent] / [_S2_K/D percent]) * CONSTANT(100))"
      ])


  describe "multi dataset", ->
    it "works in a single-dataset case", ->
      applySpecs = [
        { name: 'Count', aggregate: 'sum', attribute: 'count' }
        { name: 'Const42', aggregate: 'constant', value: 42 }
      ]

      applySimplifier = new ApplySimplifier()
      applySimplifier.addApplies(applySpecs.map(FacetApply.fromSpec))

      appliesByDataset = applySimplifier.getSimpleAppliesByDataset()
      postProcessors = applySimplifier.getPostProcessors()
      expect(postProcessors).to.have.length(1)

      row = { Count: 6 }
      postProcessors[0](row)
      expect(row).to.deep.equal({ Count: 6, Const42: 42 })

      expect(appliesByDataset).to.be.an('object')
      expect(appliesByDataset.main).to.have.length(1)
      expect(appliesByDataset.main.map(getValueOf)).to.deep.equal([
        {
          name: 'Count', aggregate: 'sum', attribute: 'count'
        }
      ])

    it "works in a simple multi-dataset case", ->
      applySpecs = [
        {
          name: 'EditsDiff'
          arithmetic: 'subtract'
          operands: [
            { dataset: 'humans', aggregate: 'sum', attribute: 'count' }
            { dataset: 'robots', aggregate: 'sum', attribute: 'count' }
          ]
        }
      ]

      applySimplifier = new ApplySimplifier()
      applySimplifier.addApplies(applySpecs.map(FacetApply.fromSpec))

      appliesByDataset = applySimplifier.getSimpleAppliesByDataset()
      postProcessors = applySimplifier.getPostProcessors()

      expect(postProcessors).to.have.length(1)
      expect(appliesByDataset).to.be.an('object')
      expect(appliesByDataset.humans[0].name[0]).to.equal('_')
      expect(appliesByDataset.robots[0].name[0]).to.equal('_')

    it "works in a simple multi-dataset case with multiple post processors", ->
      applySpecs = [
        {
          name: 'EditsDiff'
          arithmetic: 'subtract'
          operands: [
            { dataset: 'humans', aggregate: 'sum', attribute: 'count' }
            { dataset: 'robots', aggregate: 'sum', attribute: 'count' }
          ]
        }
        {
          name: 'EditsSum'
          arithmetic: 'add'
          operands: [
            { dataset: 'humans', aggregate: 'sum', attribute: 'count' }
            { dataset: 'robots', aggregate: 'sum', attribute: 'count' }
          ]
        }
      ]

      applySimplifier = new ApplySimplifier()
      applySimplifier.addApplies(applySpecs.map(FacetApply.fromSpec))

      appliesByDataset = applySimplifier.getSimpleAppliesByDataset()
      postProcessors = applySimplifier.getPostProcessors()

      expect(postProcessors).to.have.length(2)
      expect(appliesByDataset).to.be.an('object')
      expect(appliesByDataset.humans[0].name[0]).to.equal('_')
      expect(appliesByDataset.robots[0].name[0]).to.equal('_')

    it "works in a simple multi-dataset case and opts for the simple name", ->
      applySpecs = [
        {
          name: 'EditsDiff'
          arithmetic: 'subtract'
          operands: [
            { dataset: 'humans', aggregate: 'sum', attribute: 'count' }
            { dataset: 'robots', aggregate: 'sum', attribute: 'count' }
          ]
        }
        { name: 'HumanCount', dataset: 'humans', aggregate: 'sum', attribute: 'count' }
        { name: 'RobotCount', dataset: 'robots', aggregate: 'sum', attribute: 'count' }
      ]

      applySimplifier = new ApplySimplifier()
      applySimplifier.addApplies(applySpecs.map(FacetApply.fromSpec))

      appliesByDataset = applySimplifier.getSimpleAppliesByDataset()
      postProcessors = applySimplifier.getPostProcessors()

      expect(postProcessors).to.have.length(1)

      row = { HumanCount: 10, RobotCount: 6 }
      postProcessors[0](row)
      expect(row).to.deep.equal({ HumanCount: 10, RobotCount: 6, EditsDiff: 4 })

      expect(appliesByDataset).to.be.an('object')
      expect(appliesByDataset.humans.map(getValueOf)).to.deep.equal([
        {
          name: 'HumanCount', dataset: 'humans', aggregate: 'sum', attribute: 'count'
        }
      ])
      expect(appliesByDataset.robots.map(getValueOf)).to.deep.equal([
        {
          name: 'RobotCount', dataset: 'robots', aggregate: 'sum', attribute: 'count'
        }
      ])

    it "works in a simple multi-dataset case with constant", ->
      applySpecs = [
        {
          name: 'EditsDiffOver2'
          arithmetic: 'divide'
          operands: [
            {
              arithmetic: 'subtract'
              operands: [
                { dataset: 'humans', aggregate: 'sum', attribute: 'count' }
                { dataset: 'robots', aggregate: 'sum', attribute: 'count' }
              ]
            }
            {
              aggregate: 'constant'
              value: 2
            }
          ]
        }
        { name: 'HumanCount', dataset: 'humans', aggregate: 'sum', attribute: 'count' }
        { name: 'RobotCount', dataset: 'robots', aggregate: 'sum', attribute: 'count' }
      ]

      applySimplifier = new ApplySimplifier()
      applySimplifier.addApplies(applySpecs.map(FacetApply.fromSpec))

      appliesByDataset = applySimplifier.getSimpleAppliesByDataset()
      postProcessors = applySimplifier.getPostProcessors()

      expect(postProcessors).to.have.length(1)

      row = { HumanCount: 10, RobotCount: 6 }
      postProcessors[0](row)
      expect(row).to.deep.equal({ HumanCount: 10, RobotCount: 6, EditsDiffOver2: 2 })

      expect(appliesByDataset).to.be.an('object')
      expect(appliesByDataset.humans.map(getValueOf)).to.deep.equal([
        {
          name: 'HumanCount', dataset: 'humans', aggregate: 'sum', attribute: 'count'
        }
      ])
      expect(appliesByDataset.robots.map(getValueOf)).to.deep.equal([
        {
          name: 'RobotCount', dataset: 'robots', aggregate: 'sum', attribute: 'count'
        }
      ])

    it "works with a custom post processor scheme", ->
      applySpecs = [
        {
          name: 'EditsDiff'
          arithmetic: 'subtract'
          operands: [
            { dataset: 'humans', aggregate: 'sum', attribute: 'count' }
            { dataset: 'robots', aggregate: 'sum', attribute: 'count' }
          ]
        }
        { name: 'HumanCount', dataset: 'humans', aggregate: 'sum', attribute: 'count' }
        { name: 'RobotCount', dataset: 'robots', aggregate: 'sum', attribute: 'count' }
      ]

      applySimplifier = new ApplySimplifier({
        postProcessorScheme: customPostProcessorScheme
      })
      applySimplifier.addApplies(applySpecs.map(FacetApply.fromSpec))

      appliesByDataset = applySimplifier.getSimpleAppliesByDataset()
      postProcessors = applySimplifier.getPostProcessors()

      expect(appliesByDataset).to.be.an('object')
      expect(appliesByDataset.humans.map(getValueOf)).to.deep.equal([
        {
          name: 'HumanCount', dataset: 'humans', aggregate: 'sum', attribute: 'count'
        }
      ])
      expect(appliesByDataset.robots.map(getValueOf)).to.deep.equal([
        {
          name: 'RobotCount', dataset: 'robots', aggregate: 'sum', attribute: 'count'
        }
      ])

      expect(postProcessors).to.deep.equal([
        'EditsDiff <- ([HumanCount] - [RobotCount])'
      ])

    it "works in the case of derived applies (dataset on leaf)", ->
      applySpecs = [
        {
          name: 'EditsDiffOver2'
          arithmetic: 'subtract'
          operands: [
            {
              arithmetic: 'divide'
              operands: [
                { dataset: 'humans', aggregate: 'sum', attribute: 'count' }
                { aggregate: 'constant', value: 2 }
              ]
            }
            {
              arithmetic: 'divide'
              operands: [
                { dataset: 'robots', aggregate: 'sum', attribute: 'count' }
                { aggregate: 'constant', value: 2 }
              ]
            }
          ]
        }
        {
          name: 'HumanCountOver2'
          arithmetic: 'divide'
          operands: [
            { dataset: 'humans', aggregate: 'sum', attribute: 'count' }
            { aggregate: 'constant', value: 2 }
          ]
        }
        {
          name: 'RobotCountOver2'
          arithmetic: 'divide'
          operands: [
            { dataset: 'robots', aggregate: 'sum', attribute: 'count' }
            { aggregate: 'constant', value: 2 }
          ]
        }
      ]

      applySimplifier = new ApplySimplifier({
        postProcessorScheme: customPostProcessorScheme
      })
      applySimplifier.addApplies(applySpecs.map(FacetApply.fromSpec))

      appliesByDataset = applySimplifier.getSimpleAppliesByDataset()
      postProcessors = applySimplifier.getPostProcessors()

      expect(appliesByDataset).to.be.an('object')
      expect(appliesByDataset.humans.map(getValueOf)).to.deep.equal([
        {
          name: 'HumanCountOver2'
          arithmetic: 'divide'
          dataset: 'humans'
          operands: [
            { aggregate: 'sum', attribute: 'count' }
            { aggregate: 'constant', value: 2 }
          ]
        }
      ])
      expect(appliesByDataset.robots.map(getValueOf)).to.deep.equal([
        {
          name: 'RobotCountOver2'
          arithmetic: 'divide'
          dataset: 'robots'
          operands: [
            { aggregate: 'sum', attribute: 'count' }
            { aggregate: 'constant', value: 2 }
          ]
        }
      ])

      expect(postProcessors).to.deep.equal([
        'EditsDiffOver2 <- ([HumanCountOver2] - [RobotCountOver2])'
      ])

    it "works in the case of derived applies (dataset on trunk)", ->
      applySpecs = [
        {
          name: 'EditsDiffOver2'
          arithmetic: 'subtract'
          operands: [
            {
              dataset: 'humans'
              arithmetic: 'divide'
              operands: [
                { aggregate: 'sum', attribute: 'count' }
                { aggregate: 'constant', value: 2 }
              ]
            }
            {
              dataset: 'robots'
              arithmetic: 'divide'
              operands: [
                { aggregate: 'sum', attribute: 'count' }
                { aggregate: 'constant', value: 2 }
              ]
            }
          ]
        }
        {
          name: 'HumanCountOver2'
          dataset: 'humans'
          arithmetic: 'divide'
          operands: [
            { aggregate: 'sum', attribute: 'count' }
            { aggregate: 'constant', value: 2 }
          ]
        }
        {
          name: 'RobotCountOver2'
          dataset: 'robots'
          arithmetic: 'divide'
          operands: [
            { aggregate: 'sum', attribute: 'count' }
            { aggregate: 'constant', value: 2 }
          ]
        }
      ]

      applySimplifier = new ApplySimplifier({
        postProcessorScheme: customPostProcessorScheme
      })
      applySimplifier.addApplies(applySpecs.map(FacetApply.fromSpec))

      appliesByDataset = applySimplifier.getSimpleAppliesByDataset()
      postProcessors = applySimplifier.getPostProcessors()

      expect(appliesByDataset).to.be.an('object')
      expect(appliesByDataset.humans.map(getValueOf)).to.deep.equal([
        {
          name: 'HumanCountOver2'
          dataset: 'humans'
          arithmetic: 'divide'
          operands: [
            { aggregate: 'sum', attribute: 'count' }
            { aggregate: 'constant', value: 2 }
          ]
        }
      ])
      expect(appliesByDataset.robots.map(getValueOf)).to.deep.equal([
        {
          name: 'RobotCountOver2'
          dataset: 'robots'
          arithmetic: 'divide'
          operands: [
            { aggregate: 'sum', attribute: 'count' }
            { aggregate: 'constant', value: 2 }
          ]
        }
      ])

      expect(postProcessors).to.deep.equal([
        'EditsDiffOver2 <- ([HumanCountOver2] - [RobotCountOver2])'
      ])

    it "breaks things down fully", ->
      applySpecs = [
        {
          name: 'EditsDiffOver2'
          arithmetic: 'subtract'
          operands: [
            {
              dataset: 'humans'
              arithmetic: 'divide'
              operands: [
                { aggregate: 'sum', attribute: 'count' }
                { aggregate: 'constant', value: 2 }
              ]
            }
            {
              dataset: 'robots'
              arithmetic: 'divide'
              operands: [
                { aggregate: 'sum', attribute: 'count' }
                { aggregate: 'constant', value: 2 }
              ]
            }
          ]
        }
        {
          name: 'HumanCountOver2'
          dataset: 'humans'
          arithmetic: 'divide'
          operands: [
            { aggregate: 'sum', attribute: 'count' }
            { aggregate: 'constant', value: 2 }
          ]
        }
        {
          name: 'RobotCountOver2'
          dataset: 'robots'
          arithmetic: 'divide'
          operands: [
            { aggregate: 'sum', attribute: 'count' }
            { aggregate: 'constant', value: 2 }
          ]
        }
      ]

      applySimplifier = new ApplySimplifier({
        postProcessorScheme: customPostProcessorScheme
        breakToSimple: true
      })
      applySimplifier.addApplies(applySpecs.map(FacetApply.fromSpec))

      appliesByDataset = applySimplifier.getSimpleAppliesByDataset()
      postProcessors = applySimplifier.getPostProcessors()

      expect(appliesByDataset).to.be.an('object')
      expect(appliesByDataset.humans.map(getValueOf)).to.deep.equal([
        {
          name: "_S1_HumanCountOver2",
          aggregate: "sum",
          dataset: "humans",
          attribute: "count"
        }
      ])
      expect(appliesByDataset.robots.map(getValueOf)).to.deep.equal([
        {
          name: "_S2_RobotCountOver2",
          aggregate: "sum",
          dataset: "robots",
          attribute: "count"
        }
      ])

      expect(postProcessors).to.deep.equal([
        "HumanCountOver2 <- ([_S1_HumanCountOver2] / CONSTANT(2))",
        "RobotCountOver2 <- ([_S2_RobotCountOver2] / CONSTANT(2))",
        "EditsDiffOver2 <- (([_S1_HumanCountOver2] / CONSTANT(2)) - ([_S2_RobotCountOver2] / CONSTANT(2)))"
      ])

    it "works with multi dataset averages", ->
      applySpecs = [
        {
          operation: 'apply'
          name: 'PriceDiff'
          arithmetic: 'subtract'
          operands: [
            {
              dataset: 'ideal-cut'
              aggregate: 'average'
              attribute: 'price'
            }
            {
              dataset: 'good-cut'
              aggregate: 'average'
              attribute: 'price'
            }
          ]
        }
        {
          operation: 'apply'
          name: 'AvgIdealPrice'
          dataset: 'ideal-cut'
          aggregate: 'average'
          attribute: 'price'
        }
        {
          operation: 'apply'
          name: 'AvgGoodPrice'
          dataset: 'good-cut'
          aggregate: 'average'
          attribute: 'price'
        }
      ]

      applySimplifier = new ApplySimplifier({
        postProcessorScheme: customPostProcessorScheme
        breakToSimple: true
        breakAverage: true
        topLevelConstant: 'process'
      })
      applySimplifier.addApplies(applySpecs.map(FacetApply.fromSpec))

      appliesByDataset = applySimplifier.getSimpleAppliesByDataset()
      postProcessors = applySimplifier.getPostProcessors()

      expect(appliesByDataset).to.be.an('object')
      expect(appliesByDataset['ideal-cut'].map(getValueOf)).to.deep.equal([
        {
          "name": "_S1_AvgIdealPrice",
          "aggregate": "sum",
          "dataset": "ideal-cut",
          "attribute": "price"
        },
        {
          "name": "_S2_AvgIdealPrice",
          "aggregate": "count",
          "dataset": "ideal-cut"
        }
      ])
      expect(appliesByDataset['good-cut'].map(getValueOf)).to.deep.equal([
        {
          "name": "_S3_AvgGoodPrice",
          "aggregate": "sum",
          "dataset": "good-cut",
          "attribute": "price"
        },
        {
          "name": "_S4_AvgGoodPrice",
          "aggregate": "count",
          "dataset": "good-cut"
        }
      ])

      expect(postProcessors).to.deep.equal([
        "AvgIdealPrice <- ([_S1_AvgIdealPrice] / [_S2_AvgIdealPrice])",
        "AvgGoodPrice <- ([_S3_AvgGoodPrice] / [_S4_AvgGoodPrice])",
        "PriceDiff <- (([_S1_AvgIdealPrice] / [_S2_AvgIdealPrice]) - ([_S3_AvgGoodPrice] / [_S4_AvgGoodPrice]))"
      ])

    it "works in the case of a delta", ->
      applySpecs = [
        {
          name: "count"
          aggregate: "sum"
          attribute: "count"
        }
        {
          name: "count_delta_"
          arithmetic: "multiply"
          operands: [
            {
              arithmetic: "divide"
              operands: [
                {
                  arithmetic: "subtract"
                  operands: [
                    {
                      dataset: "main"
                      aggregate: "sum"
                      attribute: "count"
                    }
                    {
                      dataset: "prev"
                      aggregate: "sum"
                      attribute: "count"
                    }
                  ]
                }
                {
                  dataset: "prev"
                  aggregate: "sum"
                  attribute: "count"
                }
              ]
            }
            {
              aggregate: "constant"
              value: 100
            }
          ]
        }
      ]

      applySimplifier = new ApplySimplifier({
        postProcessorScheme: customPostProcessorScheme
      })
      applySimplifier.addApplies(applySpecs.map(FacetApply.fromSpec))

      appliesByDataset = applySimplifier.getSimpleAppliesByDataset()
      postProcessors = applySimplifier.getPostProcessors()

      expect(applySimplifier.getApplyComponents("count_delta_").map((apply) -> apply.valueOf())).to.deep.equal([
        {
          "name": "count",
          "aggregate": "sum",
          "attribute": "count"
        },
        {
          "name": "_S2_count_delta_",
          "dataset": "prev",
          "aggregate": "sum",
          "attribute": "count"
        }
      ])

      expect(appliesByDataset).to.be.an('object')
      expect(appliesByDataset.main.map(getValueOf)).to.deep.equal([
        {
          name: "count"
          aggregate: "sum"
          attribute: "count"
        }
      ])
      expect(appliesByDataset.prev.map(getValueOf)).to.deep.equal([
        {
          dataset: "prev"
          name: "_S2_count_delta_"
          aggregate: "sum"
          attribute: "count"
        }
      ])

      expect(postProcessors).to.deep.equal([
        'count_delta_ <- ((([count] - [_S2_count_delta_]) / [_S2_count_delta_]) * CONSTANT(100))'
      ])
