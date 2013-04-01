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
  name: 'SomeConstant'
  aggregate: 'constant'
  value: 1337
}
```

SQL:

```sql
1337 AS "SomeConstant"
```

#### count

Facet:

```javascript
{
  name: 'Count'
  aggregate: 'count'
}
```

SQL:

```sql
COUNT(1) AS "Count"
```

#### sum, average, min, max, uniqueCount

Facet:
```javascript
{
  name: 'Revenue'
  aggregate: 'sum' # / average / min / max / uniqueCount
  attribute: 'revenue' # This is a druid 'metric' or a SQL column
}
```

SQL:

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
  name: 'Revenue from Honda'
  aggregate: 'sum' # / average / min / max / uniqueCount
  attribute: 'revenue' # This is a druid 'metric' or a SQL column
  filter: { type: 'is', attribute: 'car_type', value: 'Honda' }
}
```

SQL:

```sql
SUM(IF(`car_type` = "Honda", `revenue`, NULL)) AS "Revenue"
AVG ...
MIN ...
MAX ...
COUNT(DISTICT ...
```

#### add, subtract, multiply, divide
Facet:
```javascript
{
  name: 'Sum Of Things'
  arithmetic: 'add' # / subtract / multiply / divide
  operands: [<apply1>, <apply2>]
}
```

SQL:

```sql
<sqlApply1> + <sqlApply2> AS "Sum Of Things"
```
