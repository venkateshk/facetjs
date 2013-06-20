`(typeof window === 'undefined' ? {} : window)['applyStringer'] = (function(module, require){"use strict"; var exports = module.exports`

arithemticMap = {
  'add': '+'
  'subtract': "-"
  'multiply': "*"
  'divide': "/"
}

convertApplyHelper = (apply, from) ->
  if apply.aggregate
    switch apply.aggregate
      when 'constant'
        expr = String(apply.value)

      when 'sum', 'min', 'max', 'uniqueCount'
        throw new Error("must have attribute") unless apply.attribute
        expr = "#{apply.aggregate}(`#{apply.attribute}`)"

      else
        throw new Error("unsupported aggregate '#{apply.aggregate}'")

  else if apply.arithmetic
    arithmetic = apply.arithmetic
    mappedArithmetic = arithemticMap[arithmetic]
    throw new Error("no such arithmetic '#{arithmetic}'") unless mappedArithmetic
    throw new Error("must have operands") unless apply.operands
    [op1, op2] = apply.operands
    expr = "#{convertApplyHelper(op1, arithmetic)} #{mappedArithmetic} #{convertApplyHelper(op2, arithmetic)}"
    if from is 'divide' or (from is 'multiply' and arithmetic in ['add', 'subtract'])
      expr = "(#{expr})"

  else
    throw new Error("must have an aggregate or an arithmetic")

  return expr


module.exports = convertApply = (apply) ->
  throw new Error("must have name") unless apply.name
  return "#{apply.name} <- #{convertApplyHelper(apply, 'add')}"

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
