# Facet

## Introduction

Facet is a framework for expressing data queries in a way that is helpful for visualizations.
Facet places the end user first by facilitating a rich query language which then gets translated to an underlying database.

## Philosophy

Facet was built with these goals in mind:

- higher level objects - a number of core datatypes are provided to make life easy.
- Serializability - facet queries and visualizations can be serialized to and from JSON
- Append-able


## Querying

Making a query using facet consists of creating a facet expression and then evaluating it.

There are a number of ways to create expressions:

- by using the ```facet()``` helper method
- by parsing an expression string using the built in parser
- by composing them manually using the Expression sub class objects
- by constructing the appropriate JSON and then deserializing it into an Expression

Expressions are composed together to create powerful queries.
These queries, which can be computer on any supported database are then executed by calling ```.compute()```.


### Example 0

Lets see a simple example of a facet query:

```javascript
var ex0 = facet() // Create an empty singleton dataset literal [{}]
  // 1 is converted into a literal
  .apply("one", 1)

  // 2 is converted into a literal via the facet() function
  .apply("two", facet(2))

  // The string "$one + $two" is parsed into an expression
  .apply("three", "$one + $two")

  // The method chaining approach is used to make an expression
  .apply("four", facet("three").add(1))

  // Simple JSON of an expression is used to define an expression
  .apply("five", {
    op: 'add'
    operands: [
      { op: 'ref', name: 'four' }
      { op: 'literal', value: 1 }
    ]
  })

  // Same as before except individual expression sub-components are parsed
  .apply("six", { op: 'add', operands: ['$five', 1] })
```

This query shows off the different ways of creating an expression.

Calling ```ex0.compute()``` will return a Q promise that will, unsurprisingly, resolve to:

```javascript
[
  {
    one: 1
    two: 2
    three: 3
    four: 4
    five: 5
    six: 6
  }
]
```

This example does not perform any useful querying or computation but does serve to illustrate the many different ways there are of defining an expression.

### Example 1

```javascript
facet(someDriverReference)
  .filter("$color = 'D'")
  .apply("priceOver2", "$price/2")
  .compute(true)
```javascript
