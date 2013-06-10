`(typeof window === 'undefined' ? {} : window)['applyStringer'] = (function(module, require){"use strict"; var exports = module.exports`

arithemticMap = {
  'add': '+'
  'subtract': "-"
  'multiply': "*"
  'divide': "/"
}

arithemticType = {
  'add': 'addition'
  'subtract': "addition"
  'multiply': "multiplication"
  'divide': "multiplication"
}

convertApplyHelper = (apply, from) ->
  if apply.aggregate
    switch apply.aggregate
      when 'constant'
        expr = String(apply.value)

      when 'sum', 'min', 'max', 'uniqueCount'
        expr = "#{apply.aggregate}(`#{apply.attribute}`)"

      else
        throw new Error("unsupported aggregate")

  else if apply.arithmetic
    arType = arithemticType[apply.arithmetic]
    mappedArithmetic = arithemticMap[apply.arithmetic]
    throw "no such arithmetic" unless mappedArithmetic
    expr = "#{convertApplyHelper(apply.operands[0], arType)} #{mappedArithmetic} #{convertApplyHelper(apply.operands[1], arType)}"
    if from is 'multiplication' and arType is 'addition'
      expr = "(#{expr})"

  return expr


module.exports = convertApply = (apply) ->
  return "#{apply.name} <- #{convertApplyHelper(apply, 'addition')}"

# console.log convertApply(
#   {
#     "name": "cpc",
#     "arithmetic": "divide",
#     "operands": [
#       {
#         "arithmetic": "divide",
#         "operands": [
#           {
#             "arithmetic": "multiply",
#             "operands": [
#               {
#                 "arithmetic": "multiply",
#                 "operands": [
#                   {
#                     "arithmetic": "divide",
#                     "operands": [
#                       {
#                         "arithmetic": "divide",
#                         "operands": [
#                           {
#                             "attribute": "revenue",
#                             "aggregate": "sum"
#                           },
#                           {
#                             "aggregate": "constant",
#                             "value": 1000
#                           }
#                         ]
#                       },
#                       {
#                         "attribute": "filled",
#                         "aggregate": "sum"
#                       }
#                     ]
#                   },
#                   {
#                     "aggregate": "constant",
#                     "value": "1000"
#                   }
#                 ]
#               },
#               {
#                 "aggregate": "constant",
#                 "value": 1000
#               }
#             ]
#           },
#           {
#             "arithmetic": "multiply",
#             "operands": [
#               {
#                 "arithmetic": "divide",
#                 "operands": [
#                   {
#                     "attribute": "clicks",
#                     "aggregate": "sum"
#                   },
#                   {
#                     "attribute": "filled",
#                     "aggregate": "sum"
#                   }
#                 ]
#               },
#               {
#                 "aggregate": "constant",
#                 "value": "100"
#               }
#             ]
#           }
#         ]
#       },
#       {
#         "aggregate": "constant",
#         "value": 1000
#       }
#     ]
#   }
# )

# -----------------------------------------------------
# Handle commonJS crap
`return module.exports; }).call(this,
  (typeof module === 'undefined' ? {exports: {}} : module),
  (typeof require === 'undefined' ? function (modulePath) {
    var moduleParts = modulePath.split('/');
    return window[moduleParts[moduleParts.length - 1]];
  } : require)
)`
