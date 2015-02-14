# The State of Things

Thank you for your interest in facet.js.

This is a short writeup of the current state of the project.
Please read it to understand where the project is right now and where is is heading.

## Where is this coming from?

facet.js became open source (under the Apache 2.0) license on Feb 20, 2015 after two years of closed source development.

facet was originally built to solve the specific problems encountered at [Metamarkets](http://metamarkets.com) while
trying to build an interactive, real-time, data exploration UI on top of the [Druid](http://druid.io) big-data database.
facet was open sourced because we believe that the challenges we encountered are not unique to the Metamarkets use case
and in-fact are applicable to anyone trying to build a data exploration UI over large amount of data.

## Current project status

Prior to being opened facet.js was re-architected and re-written to become more general and easier to understand.
The rewrite was also necessary to facilitate some of the new features that re coming down the pipeline.
The rewrite is not fully compete and as a result facet.js is currently divided into two domains `core` and `legacy`.

`core` represents the new language for expressing queries and the start of the general query planner.

`legacy` represents the old language that will soon be gone. You can see it documented [here](legacy.md).

The basic facet workflow consists of composing an expression and passing it to a driver that can evaluate it.
As of this writing the driver for Druid and MySQL only exist only within the `legacy` module, this means that for now
the only way to query Druid via facet is by wrapping the legacy driver in the legacy translator. Since the legacy
language is less expressive than the new language, there are certain expressions that are possible in the new language
that can not be translated.

## What's next?

### Finish migration to core

The main priority for the facet team is to get all the existing drivers ported into `core` and extended to support all
the goodness that the new query language allows.

### Round out the query language support

Due to the fact that facet was initially developed to solve the Metamarkets use case certain parts of the legacy drivers
are more developed than others. As part of the open sourcing effort (and the migration to `core` all features will be
supported equally).

### Integrate in the visualization engine

This is the component that truly necessitated the refactor. More on this later.
