# Is NULL a core data type?
# NUMERIC null treated as 0?

value types:
  Null
  Boolean
  Number
  NumberRange
  String
  Date
  TimeRange
  Set(string)

  Dataset

  Shape
  Scale
  Mark



public resolveType(typeInfo: TypeInfo): Expression {

}


Add type that can potentially be resolved later types can not resolve in place
typeResolved == (this.type != null)
need global simple,
Add methods:
checkType(typeInfo: TypeInfo)
and .type instance variable
optional type on refs
Expression {
  #NULL
  { op: 'literal', value: null }

  #BOOLEAN
  { op: 'literal', value: true/false }
  { op: 'ref', name: 'is_robot', options?: NativeOptions }
  { op: 'is', lhs: T, rhs: T }
  { op: 'lessThan', lhs: NUMERIC, rhs: NUMERIC }
  { op: 'lessThanOrEqual', lhs: NUMERIC, rhs: NUMERIC }
  { op: 'greaterThan', lhs: NUMERIC, rhs: NUMERIC }
  { op: 'greaterThanOrEqual', lhs: NUMERIC, rhs: NUMERIC }
  { op: 'in', lhs: CATEGORICAL, rhs: CATEGORICAL_SET }
  { op: 'in', lhs: NUMERIC, rhs: NUMERIC_RANGE }
  { op: 'in', lhs: TIME, rhs: TIME_RANGE }
  { op: 'match', regexp: '^\d+', operand: CATEGORICAL }
  { op: 'not', operand: BOOLEAN }
  { op: 'and', operands: [BOOLEAN, BOOLEAN, ...] }
  { op: 'or', operands: [BOOLEAN, BOOLEAN, ...] }

  #NUMBER
  { op: 'literal', value: 6 }
  { op: 'negate', operand: NUMERIC }
  { op: 'reciprocal', operand: NUMERIC }
  { op: 'ref', name: 'revenue', options?: NativeOptions }
  { op: 'alternative', operands: [NUMERIC, NUMERIC, ...] }
  { op: 'add', operands: [NUMERIC, NUMERIC, ...] }
  { op: 'multiply', operands: [NUMERIC, NUMERIC, ...] }
  { op: 'min', operands: [NUMERIC, NUMERIC, ...] }
  { op: 'max', operands: [NUMERIC, NUMERIC, ...] }
  { op: 'aggregate', operand: DATASET, fn: 'sum', attribute: EXPRESSION }

  #TIME
  { op: 'literal', value: Time }
  { op: 'ref', name: 'timestamp', options?: NativeOptions }
  { op: 'offset', operand: TIME, duration: 'P1D' }

  #STRING
  { op: 'literal', value: 'Honda' }
  { op: 'ref', type: 'categorical', name: 'make', options?: NativeOptions }
  { op: 'concat', operands: [CATEGORICAL, CATEGORICAL, ...] }

  #NUMBER_RANGE
  { op: 'literal', value: [0.05, 0.1] }
  { op: 'ref', name: 'revenue_range', options?: NativeOptions }
  { op: 'range', lhs: NUMERIC, rhs: NUMERIC }
  { op: 'bucket', operand: NUMERIC, size: 0.05, offset: 0.01 }

  #TIME_RANGE
  { op: 'literal', value: { type: 'TIME_RANGE', start: ..., end: ...} }
  { op: 'ref', name: 'flight_time', options?: NativeOptions }
  { op: 'range', lhs: TIME, rhs: TIME }
  { op: 'bucket', operand: TIME, duration: 'P1D' }

  #CATEGORICAL_SET
  { op: 'literal', value: ['Honda', 'BMW', 'Suzuki'] }
  { op: 'ref', name: 'authors', options?: NativeOptions }

  #DATASET
  { op: 'literal', value: <Dataset> }
  { op: 'split', operand: DATASET, attribute: EXPRESSION, name: 'splits' }
  { op: 'actions', operand: DATASET, actions: [Actions*] }
}

Actions {
  { action: 'apply', name: 'blah', expression: Expression }
  { action: 'filter', expression: Expression }
  { action: 'sort', expression: Expression, direction: 'ascending' }
}

# ToDo: op: 'bucket'

$color = 'D' and $cut = 'good' and $language = 'en'

apply colorPart, $color = 'D'
apply nonColorPart, $cut = 'good' and $language = 'en'
colorPart and nonColorPart



apply _ds1_stuff, $ds1.count()
apply _ds2_stuff, $ds2.count()

$ds1.count() / $ds2.count()










myDataset = new Dataset({})

query = {
  op: 'actions',
  actions: [
    {
      action: "apply",
      name: "diamonds",
      expression: {
        op: 'actions',
        operand: {
          op: 'literal',
          value: myDataset
        }
        actions: [
          {
            action: 'filter',
            expression: {
              op: 'equals'
              lhs: {op: 'ref', name: 'color'}
              rhs: {op: 'literal', value: 'D'}
            }
          }
        ]
      }
    }
    {
      action: "apply",
      name: "SumAdded",
      expression: {
        op: 'aggregate',
        aggregate: 'sum',
        operand: {
          op: 'ref',
          name: 'diamonds'
        },
        attribute: {
          op: 'ref'
          name: 'added'
        }
      }
    }
    {
      action: "apply",
      name: "Count",
      expression: {
        op: 'aggregate',
        aggregate: 'count',
        operand: {
          op: 'ref',
          name: 'diamonds'
        }
      }
    }
    {
      name: "Languages",
      expression: {
        op: 'actions'
        operand: {
          op: 'split'
          operand: {
            op: 'ref',
            name: 'diamonds'
          }
          attribute: {op: 'ref', name: 'language'}
          name: 'Language'
        }
        actions: [
          {action: "apply", name: "diamonds", expression: "map(.added) | add"}
          {action: "apply", name: "SumAdded", expression: "map(.added) | add"}
          {action: "apply", name: "Count", expression: "length"}
          {action: "sort", sort: 'Count', direction: 'descending'}
          {action: "limit", limit: 10}
        ]
      }
    }
  ]
}




