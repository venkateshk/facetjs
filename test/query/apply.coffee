chai = require("chai")
expect = chai.expect

{FacetApply} = require('../../build/query')

describe "FacetApply", ->
  describe "error", ->
    it "throws on bad input", ->
      applySpec = "hello world"
      expect(-> FacetApply.fromSpec(applySpec)).to.throw(Error, "unrecognizable apply")

    it "throws on no aggregate or arithmetic", ->
      applySpec = {}
      expect(-> FacetApply.fromSpec(applySpec)).to.throw(Error, "must have an aggregate or arithmetic")

    it "throws on bad aggregate", ->
      applySpec = { aggregate: ['wtf?'] }
      expect(-> FacetApply.fromSpec(applySpec)).to.throw(Error, "aggregate must be a string")

    it "throws on bad arithmetic", ->
      applySpec = { arithmetic: ['wtf?'] }
      expect(-> FacetApply.fromSpec(applySpec)).to.throw(Error, "arithmetic must be a string")

    it "throws on unknown aggregate", ->
      applySpec = { aggregate: 'poo' }
      expect(-> FacetApply.fromSpec(applySpec)).to.throw(Error, "unsupported aggregate 'poo'")

    it "throws on unknown arithmetic", ->
      applySpec = { arithmetic: 'poo' }
      expect(-> FacetApply.fromSpec(applySpec)).to.throw(Error, "unsupported arithmetic 'poo'")

    it "throws on bad name", ->
      applySpec = { aggregate: 'count', name: ["wtf?"] }
      expect(-> FacetApply.fromSpec(applySpec)).to.throw(Error, "apply name must be a string")

    it "throws on bad attribute", ->
      applySpec = { aggregate: 'sum', attribute: ["wtf?"] }
      expect(-> FacetApply.fromSpec(applySpec)).to.throw(Error, "attribute must be a string")

    it "throws on on dataset conflict", ->
      applySpec = {
        name: "lag"
        dataset: "somedata"
        arithmetic: "divide"
        operands: [
          {
            arithmetic: "divide"
            operands: [
              {
                dataset: "somedata"
                aggregate: "sum"
                attribute: "value"
              }
              {
                dataset: "otherdata"
                aggregate: "sum"
                attribute: "count"
              }
            ]
          }
          {
            aggregate: "constant"
            value: 3600
          }
        ]
      }
      expect(-> FacetApply.fromSpec(applySpec)).to.throw(Error, "dataset conflict between 'somedata' and 'otherdata'")


  describe "preserves", ->
    it "constant", ->
      applySpec = {
        name: "Count"
        aggregate: 'constant'
        value: 42
      }
      expect(FacetApply.fromSpec(applySpec).valueOf()).to.deep.equal(applySpec)

    it "constant with dataset", ->
      applySpec = {
        name: "Count"
        dataset: "irrelevant"
        aggregate: 'constant'
        value: 42
      }
      expect(FacetApply.fromSpec(applySpec).valueOf()).to.deep.equal({
        name: "Count"
        aggregate: 'constant'
        value: 42
      })

    it "count", ->
      applySpec = {
        name: "Count"
        aggregate: 'count'
      }
      expect(FacetApply.fromSpec(applySpec).valueOf()).to.deep.equal(applySpec)

    it "count with dataset", ->
      applySpec = {
        name: "Count"
        dataset: 'mydata'
        aggregate: 'count'
      }
      expect(FacetApply.fromSpec(applySpec).valueOf()).to.deep.equal(applySpec)

    it "quantile", ->
      applySpec = {
        name: "p99"
        aggregate: 'quantile'
        attribute: 'bid_hist'
        quantile: 0.99
        options: {
          druidLowerLimit: 0
          druidLowerUpper: 10
          druidResolution: 200
        }
      }
      expect(FacetApply.fromSpec(applySpec).valueOf()).to.deep.equal(applySpec)

    it "complex", ->
      applySpec = {
        name: "lag"
        arithmetic: "divide"
        operands: [
          {
            arithmetic: "divide"
            operands: [
              {
                aggregate: "sum"
                attribute: "value"
              }
              {
                aggregate: "sum"
                attribute: "count"
              }
            ]
          }
          {
            aggregate: "constant"
            value: 3600
          }
        ]
      }
      expect(FacetApply.fromSpec(applySpec).valueOf()).to.deep.equal(applySpec)

    it "filtered", ->
      applySpec = {
        name: "Count R=0"
        aggregate: "sum", attribute: "count"
        filter: { type: 'is', attribute: "robot", value: "0" }
      }
      expect(FacetApply.fromSpec(applySpec).valueOf()).to.deep.equal(applySpec)

    it "complex with dataset", ->
      applySpec = {
        name: "lag"
        arithmetic: "divide"
        operands: [
          {
            arithmetic: "divide"
            dataset: "somedata"
            operands: [
              {
                dataset: "somedata"
                aggregate: "sum"
                attribute: "value"
              }
              {
                dataset: "somedata"
                aggregate: "sum"
                attribute: "count"
              }
            ]
          }
          {
            aggregate: "constant"
            value: 3600
          }
        ]
      }
      expect(FacetApply.fromSpec(applySpec).valueOf()).to.deep.equal({
        name: "lag"
        arithmetic: "divide"
        operands: [
          {
            arithmetic: "divide"
            dataset: "somedata"
            operands: [
              {
                aggregate: "sum"
                attribute: "value"
              }
              {
                aggregate: "sum"
                attribute: "count"
              }
            ]
          }
          {
            aggregate: "constant"
            value: 3600
          }
        ]
      })

    it "complex multi-dataset", ->
      applySpec = {
        name: 'EditsDiff'
        arithmetic: 'subtract'
        operands: [
          { dataset: 'humans', aggregate: 'sum', attribute: 'count' }
          { dataset: 'robots', aggregate: 'sum', attribute: 'count' }
        ]
      }
      expect(FacetApply.fromSpec(applySpec).valueOf()).to.deep.equal(applySpec)


  describe "toString", ->
    it "complex divide", ->
      applySpec = {
        name: "lag"
        arithmetic: "divide"
        operands: [
          {
            arithmetic: "divide"
            operands: [
              {
                aggregate: "sum"
                attribute: "value"
              }
              {
                aggregate: "sum"
                attribute: "count"
              }
            ]
          }
          {
            aggregate: "constant"
            value: 3600
          }
        ]
      }
      expect(FacetApply.fromSpec(applySpec).toString()).to.equal("lag <- (sum(value) / sum(count)) / 3600")

    it "complex multiply", ->
      applySpec = {
        name: "lag"
        arithmetic: "multiply"
        operands: [
          {
            arithmetic: "multiply"
            operands: [
              {
                aggregate: "sum"
                attribute: "value"
              }
              {
                aggregate: "sum"
                attribute: "count"
              }
            ]
          }
          {
            aggregate: "constant"
            value: 3600
          }
        ]
      }
      expect(FacetApply.fromSpec(applySpec).toString()).to.equal("lag <- sum(value) * sum(count) * 3600")

  describe "isEqual", ->
    it "returns false for other types", ->
      expect(FacetApply.fromSpec({aggregate: 'count'}).isEqual(null)).to.be.false

    it "each pair is only equal to itself", ->
      applySpecs = [
        {
          aggregate: "count"
        }
        {
          aggregate: "sum"
          attribute: "count"
        }
        {
          aggregate: "sum"
          attribute: "count"
          dataset: 'moon'
        }
        {
          arithmetic: "multiply"
          operands: [
            {
              aggregate: "max"
              attribute: "value"
            }
            {
              aggregate: "min"
              attribute: "count"
            }
          ]
        }
        {
          arithmetic: "divide"
          operands: [
            {
              aggregate: "max"
              attribute: "value"
            }
            {
              aggregate: "min"
              attribute: "count"
            }
          ]
        }
        {
          arithmetic: "divide"
          operands: [
            {
              aggregate: "sum"
              attribute: "value"
            }
            {
              aggregate: "sum"
              attribute: "count"
            }
          ]
        }
        {
          arithmetic: "divide"
          operands: [
            {
              arithmetic: "divide"
              operands: [
                {
                  aggregate: "sum"
                  attribute: "value"
                }
                {
                  aggregate: "sum"
                  attribute: "count"
                }
              ]
            }
            {
              aggregate: "constant"
              value: 3600
            }
          ]
        }
      ]
      for applySpec1, i in applySpecs
        for applySpec2, j in applySpecs
          try
            expect(FacetApply.fromSpec(applySpec1).isEqual(FacetApply.fromSpec(applySpec2))).to.equal(i is j)
          catch e
            console.log 'applySpec1', applySpec1
            console.log 'applySpec2', applySpec2
            console.log 'res', FacetApply.fromSpec(applySpec1).isEqual(FacetApply.fromSpec(applySpec2))
            throw new Error("expected apply to be #{if i is j then 'equal' else 'unequal'}")


  describe "segregate", ->
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

    it "works in a single-dataset case", ->
      applySpecs = [
        { name: 'Count', aggregate: 'sum', attribute: 'count' }
        { name: 'Const42', aggregate: 'constant', value: 42 }
      ]

      {
        appliesByDataset
        postProcessors
        trackedSegregation
      } = FacetApply.segregate(applySpecs.map(FacetApply.fromSpec))
      expect(trackedSegregation).to.be.null
      expect(postProcessors).to.have.length(1)

      row = { Count: 6 }
      postProcessors[0](row)
      expect(row).to.deep.equal({ Count: 6, Const42: 42 })

      expect(appliesByDataset).to.be.an('object')
      expect(appliesByDataset.main).to.have.length(1)
      expect(appliesByDataset.main[0].valueOf()).to.deep.equal({
        name: 'Count', aggregate: 'sum', attribute: 'count'
      })

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

      {
        appliesByDataset
        postProcessors
        trackedSegregation
      } = FacetApply.segregate(applySpecs.map(FacetApply.fromSpec))
      expect(trackedSegregation).to.be.null
      expect(postProcessors).to.have.length(1)
      expect(appliesByDataset).to.be.an('object')
      expect(appliesByDataset.humans).to.have.length(1)
      expect(appliesByDataset.robots).to.have.length(1)
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

      {
        appliesByDataset
        postProcessors
        trackedSegregation
      } = FacetApply.segregate(applySpecs.map(FacetApply.fromSpec))
      expect(trackedSegregation).to.be.null
      expect(postProcessors).to.have.length(2)
      expect(appliesByDataset).to.be.an('object')
      expect(appliesByDataset.humans).to.have.length(1)
      expect(appliesByDataset.robots).to.have.length(1)
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

      {
        appliesByDataset
        postProcessors
        trackedSegregation
      } = FacetApply.segregate(applySpecs.map(FacetApply.fromSpec))
      expect(trackedSegregation).to.be.null
      expect(postProcessors).to.have.length(1)

      row = { HumanCount: 10, RobotCount: 6 }
      postProcessors[0](row)
      expect(row).to.deep.equal({ HumanCount: 10, RobotCount: 6, EditsDiff: 4 })

      expect(appliesByDataset).to.be.an('object')
      expect(appliesByDataset.humans).to.have.length(1)
      expect(appliesByDataset.robots).to.have.length(1)
      expect(appliesByDataset.humans[0].valueOf()).to.deep.equal({
        name: 'HumanCount', dataset: 'humans', aggregate: 'sum', attribute: 'count'
      })
      expect(appliesByDataset.robots[0].valueOf()).to.deep.equal({
        name: 'RobotCount', dataset: 'robots', aggregate: 'sum', attribute: 'count'
      })

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

      {
        appliesByDataset
        postProcessors
        trackedSegregation
      } = FacetApply.segregate(applySpecs.map(FacetApply.fromSpec))
      expect(trackedSegregation).to.be.null
      expect(postProcessors).to.have.length(1)

      row = { HumanCount: 10, RobotCount: 6 }
      postProcessors[0](row)
      expect(row).to.deep.equal({ HumanCount: 10, RobotCount: 6, EditsDiffOver2: 2 })

      expect(appliesByDataset).to.be.an('object')
      expect(appliesByDataset.humans).to.have.length(1)
      expect(appliesByDataset.robots).to.have.length(1)
      expect(appliesByDataset.humans[0].valueOf()).to.deep.equal({
        name: 'HumanCount', dataset: 'humans', aggregate: 'sum', attribute: 'count'
      })
      expect(appliesByDataset.robots[0].valueOf()).to.deep.equal({
        name: 'RobotCount', dataset: 'robots', aggregate: 'sum', attribute: 'count'
      })

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

      {
        appliesByDataset
        postProcessors
        trackedSegregation
      } = FacetApply.segregate(applySpecs.map(FacetApply.fromSpec), null, customPostProcessorScheme)
      expect(trackedSegregation).to.be.null
      expect(postProcessors).to.have.length(1)
      expect(postProcessors[0]).to.equal('EditsDiff <- ([HumanCount] - [RobotCount])')

      expect(appliesByDataset).to.be.an('object')
      expect(appliesByDataset.humans).to.have.length(1)
      expect(appliesByDataset.robots).to.have.length(1)
      expect(appliesByDataset.humans[0].valueOf()).to.deep.equal({
        name: 'HumanCount', dataset: 'humans', aggregate: 'sum', attribute: 'count'
      })
      expect(appliesByDataset.robots[0].valueOf()).to.deep.equal({
        name: 'RobotCount', dataset: 'robots', aggregate: 'sum', attribute: 'count'
      })

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

      {
        appliesByDataset
        postProcessors
        trackedSegregation
      } = FacetApply.segregate(applySpecs.map(FacetApply.fromSpec), null, customPostProcessorScheme)
      expect(trackedSegregation).to.be.null
      expect(postProcessors).to.have.length(1)
      expect(postProcessors[0]).to.equal('EditsDiffOver2 <- ([HumanCountOver2] - [RobotCountOver2])')

      expect(appliesByDataset).to.be.an('object')
      expect(appliesByDataset.humans).to.have.length(1)
      expect(appliesByDataset.robots).to.have.length(1)
      expect(appliesByDataset.humans[0].valueOf()).to.deep.equal({
        name: 'HumanCountOver2'
        arithmetic: 'divide'
        operands: [
          { dataset: 'humans', aggregate: 'sum', attribute: 'count' }
          { aggregate: 'constant', value: 2 }
        ]
      })
      expect(appliesByDataset.robots[0].valueOf()).to.deep.equal({
        name: 'RobotCountOver2'
        arithmetic: 'divide'
        operands: [
          { dataset: 'robots', aggregate: 'sum', attribute: 'count' }
          { aggregate: 'constant', value: 2 }
        ]
      })


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

      {
        appliesByDataset
        postProcessors
        trackedSegregation
      } = FacetApply.segregate(applySpecs.map(FacetApply.fromSpec), null, customPostProcessorScheme)
      expect(trackedSegregation).to.be.null
      expect(postProcessors).to.have.length(1)
      expect(postProcessors[0]).to.equal('EditsDiffOver2 <- ([HumanCountOver2] - [RobotCountOver2])')

      expect(appliesByDataset).to.be.an('object')
      expect(appliesByDataset.humans).to.have.length(1)
      expect(appliesByDataset.robots).to.have.length(1)
      expect(appliesByDataset.humans[0].valueOf()).to.deep.equal({
        name: 'HumanCountOver2'
        dataset: 'humans'
        arithmetic: 'divide'
        operands: [
          { aggregate: 'sum', attribute: 'count' }
          { aggregate: 'constant', value: 2 }
        ]
      })
      expect(appliesByDataset.robots[0].valueOf()).to.deep.equal({
        name: 'RobotCountOver2'
        dataset: 'robots'
        arithmetic: 'divide'
        operands: [
          { aggregate: 'sum', attribute: 'count' }
          { aggregate: 'constant', value: 2 }
        ]
      })




