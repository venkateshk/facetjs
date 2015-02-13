# facet.js

## Introduction

facet.js is a framework for expressing data queries in a way that is helpful for visualizations.
facet.js places the end user first by facilitating a rich query language which then gets translated to an underlying database.

## Philosophy

facet.js was built with these goals in mind:

### Higher level language

A high level domain specific language is employed to describe the facet API.
This language is inspired by Hadley Wickham's [split-apply-combine](http://www.jstatsoft.org/v40/i01/paper) principle,
and by [jq](https://stedolan.github.io/jq/).

### Higher level objects

A number of core datatypes are provided to make life easy.

### Serializability

facet queries and visualizations can be serialized to and from JSON

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

Here is an example of a simple facet query that illustrates the different ways by which expressions can be created:

```javascript
var ex0 = facet() // Create an empty singleton dataset literal [{}]
  // 1 is converted into a literal
  .def("one", 1)

  // 2 is converted into a literal via the facet() function
  .def("two", facet(2))

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

Calling ```ex0.compute()``` will return a Q promise that will resolve to:

```javascript
[
  {
    three: 3
    four: 4
    five: 5
    six: 6
  }
]
```

This example employees three functions:

`facet()` creates a dataset with one empty datum inside of it. This is the base of most facet operations.

`apply(name, expression)` evaluates the given `expression` for every element of the dataset and saves the result as `name`

`def(name, expression)` is essentially the same as `apply` except that the result will not show up in the output.
This can be used for temporary computations.


### Example 1

```javascript
var remoteDatasetDescription = /* a description of the remote dataset (fill me in */

var ex1 = facet(remoteDatasetDescription)
  .filter("$color = 'D'")
  .apply("priceOver2", "$price/2")
  .compute()
```
