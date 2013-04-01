# Facet

## Drivers

### Filter
ToDo

### Split
ToDo

### Apply
An apply is a function that takes an array of rows and returns a number.

How facet applies work:

#### constant
Facet:

```javascript
{
  operation: 'apply'
  name: 'SomeConstant'
  aggregate: 'constant'
  value: 1337
}
```

SQL SELECT:

```sql
1337 AS "SomeConstant"
```

#### count

Facet:
```javascript
{
  operation: 'apply'
  name: 'Count'
  aggregate: 'count'
}
```

SQL SELECT:
```sql
COUNT(1) AS "Count"
```

#### sum, average, min, max, uniqueCount

Facet:
```javascript
{
  operation: 'apply'
  name: 'Revenue'
  aggregate: 'sum' // average / min / max / uniqueCount
  attribute: 'revenue' // This is a druid 'metric' or a SQL column
}
```

SQL SELECT:
```sql
SUM(`revenue`) AS "Revenue"
AVG ...
MIN ...
MAX ...
COUNT(DISTICT ...
```

#### filtered applies
Each apply above can also be filtered with a filter property

Facet:
```javascript
{
  operation: 'apply'
  name: 'Revenue from Honda'
  aggregate: 'sum' // average / min / max / uniqueCount
  attribute: 'revenue' // This is a druid 'metric' or a SQL column
  filter: { type: 'is', attribute: 'car_type', value: 'Honda' }
}
```

SQL SELECT:
```sql
SUM(IF(`car_type` = "Honda", `revenue`, NULL)) AS "Revenue"
AVG ...
MIN ...
MAX ...
COUNT(DISTICT ...
```

#### add, subtract, multiply, divide
Note that for nested applies the keys ```operation: 'apply'``` and ```name``` need only to appear on the outer-most apply

Facet:
```javascript
{
  operation: 'apply'
  name: 'Sum Of Things'
  arithmetic: 'add' // subtract / multiply / divide
  operands: [<apply1>, <apply2>]
}
```

SQL SELECT:
```sql
<sqlApply1> + <sqlApply2> AS "Sum Of Things"
```

### Combine
ToDo

