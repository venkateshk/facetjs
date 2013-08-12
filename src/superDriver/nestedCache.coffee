exports.pivotSuperDriver = do ->
  # Get the split and combines grouped together
  getSplitCombines = (query) ->
    splitCombines = query.getGroups().map(({split, combine}) -> { split, combine })
    splitCombines.shift()
    return splitCombines

  # Compares that the split combines are the same ignoring the bucket filters
  isSameSplitCombine = (splitCombine1, splitCombine2) ->
    split1 = _.clone(splitCombine1.split)
    split2 = _.clone(splitCombine2.split)
    delete split1.bucketFilter
    delete split2.bucketFilter
    return _.isEqual(split1, split2) and _.isEqual(splitCombine1.combine, splitCombine2.combine)

  # Get a single set of applies, this assumes that the same applies are executer on each split
  getApplies = (query) ->
    return query.getGroups()[0].applies

  # Computes the diff between sup & sub assumes that sup and sub are either atomic or an AND of atomic filters
  filterDiff = (sup, sub) ->
    sup = (if not sup then [] else if sup.type is 'and' then sup.filters else [sup])
    sub = (if not sub then [] else if sub.type is 'and' then sub.filters else [sub])
    throw new Error('sup can not be or have OR types') if sup.some(({type}) -> type is 'or')
    throw new Error('sub can not be or have OR types') if sub.some(({type}) -> type is 'or')

    filterInSub = (filter) ->
      for subFilter in sub
        return true if filter.isEqual(subFilter)
      return false

    diff = []
    numFoundInSub = 0
    for supFilter in sup
      if filterInSub(supFilter)
        numFoundInSub++
      else
        diff.push supFilter

    return if numFoundInSub is sub.length then diff else null

  # -----------
  andFilterToPath = (splitNames, andFilter) ->
    return [andFilter.value] if andFilter.type is 'is'
    if andFilter.type isnt 'and' or andFilter.filters.some(({type}) -> type isnt 'is')
      throw new TypeError("unsupported AND filter")

    return andFilter.filters.slice()
      .sort((f1, f2) -> splitNames.indexOf(f1.prop) - splitNames.indexOf(f2.prop))
      .map(({value}) -> value)

  getCanonicalSplitTreePaths = (query) ->
    splits = query.filter(({operation}) -> operation is 'split')
    splitNames = splits.map((d) -> d.name)
    paths = []

    for split in splits
      bucketFilter = split.bucketFilter
      continue unless bucketFilter
      switch bucketFilter.type
        when 'is', 'and'
          orFilters = [bucketFilter]
        when 'or'
          orFilters = bucketFilter.filters
        when 'false'
          orFilters = []
        else
          throw new TypeError("unsupported OR filter")

      for filter in orFilters
        paths.push(andFilterToPath(splitNames, filter))

    return paths

  rangeSep = ' }woop_woop{ '
  condenseRange = (v) ->
    return if Array.isArray(v) then v.join(rangeSep) else v

  expandRange = (v) ->
    return if v.indexOf(rangeSep) isnt -1 then v.split(rangeSep) else v

  getPathDiff = (oldQuery, newQuery) ->
    sep = ' >#>#> ' # Sort of hacky as it assumes that 'sep' is never in the data
    oldTreePaths = getCanonicalSplitTreePaths(oldQuery).map((path) -> path.map(condenseRange).join(sep))
    newTreePaths = getCanonicalSplitTreePaths(newQuery).map((path) -> path.map(condenseRange).join(sep))
    return {
      added:   _.difference(newTreePaths, oldTreePaths).map((path) -> path.split(sep).map(expandRange))
      removed: _.difference(oldTreePaths, newTreePaths).map((path) -> path.split(sep).map(expandRange))
    }

  findInData = (data, path, splitCombines) ->
    for part, i in path
      splitName = splitCombines[i].split.name
      return unless data.splits
      found = _.find(data.splits, (split) -> _.isEqual(split.prop?[splitName], part))
      return unless found
      data = found
    return data

  driverLog = (str) ->
    #console.log "SUPER DRIVER: #{str}"
    return

  return ({transport, onData}) ->
    queryChain = []
    running = false
    myQuery = null
    myData = null

    myOnData = (data, state) ->
      onData(data, state)
      if state is 'final'
        running = false
        makeStep()
      return

    # Makes the query and saves the query and the result as the last results
    makeFullQuery = (newQuery, keep) ->
      myOnData(null, 'intermediate') unless keep
      transport {query: newQuery}, (err, newData) ->
        if err
          myOnData(null, 'final')
          return

        myQuery = newQuery
        myData = newData
        driverUtil.parentify(myData)
        myOnData(myData, 'final')
        return

    makeStep = ->
      return if running or queryChain.length is 0
      running = true
      newQuery = queryChain.shift()

      if not myQuery
        driverLog 'I am empty, give up'
        makeFullQuery(newQuery)
        return

      # Make sure the apples match
      myApplies = getApplies(myQuery)
      newApplies = getApplies(newQuery)
      if not _.isEqual(newApplies, myApplies)
        driverLog 'applies do not match, give up'
        makeFullQuery(newQuery)
        return

      myFilter = myQuery.getFilter()
      newFilter = newQuery.getFilter()
      diff = filterDiff(newFilter, myFilter)
      if not diff
        driverLog 'new filters are not a superset, give up'
        makeFullQuery(newQuery)
        return

      # Check splits
      mySplitCombines = getSplitCombines(myQuery)
      newSplitCombines = getSplitCombines(newQuery)

      # Some splits were removed from the beginning and added as filters.
      if diff.length and mySplitCombines.length > newSplitCombines.length
        # Assume that the new split combines represent the tail of the old splits
        splitCombineOffset = mySplitCombines.length - newSplitCombines.length

        # Check that the splits align up
        if not newSplitCombines.every((newSplitCombine, i) -> isSameSplitCombine(newSplitCombine, mySplitCombines[i + splitCombineOffset]))
          myOnData(null, 'intermediate')
          driverLog 'splits are different, give up'
          makeFullQuery(newQuery)
          return

        splitIdx = 0
        myDataRef = myData
        while splitIdx < splitCombineOffset
          mySplit = mySplitCombines[splitIdx].split
          splitFilter = _.find(diff, (d) -> d.type is 'is' and d.attribute is mySplit.attribute)
          if not splitFilter
            driverLog 'filter change does not make sense, give up'
            makeFullQuery(newQuery)
            return

          # ToDo: revisit 'is' with time filters
          myDataRef = _.find(myDataRef.splits, (split) -> split.prop[mySplit.name] is splitFilter.value)
          if not myDataRef
            driverLog 'filter change does not work out, give up'
            makeFullQuery(newQuery)
            return

          splitIdx++

        myQuery = newQuery
        myData = myDataRef
        myData.parent = null
        driverLog 'win, subtree filter :-)'
        myOnData(myData, 'final')

      else if diff.length is 0 and mySplitCombines.length < newSplitCombines.length
        # Check that the split-combines align up
        i = 0
        while i < mySplitCombines.length
          mySplitCombine = mySplitCombines[i]
          newSplitCombine = newSplitCombines[i]
          if not _.isEqual(mySplitCombine, newSplitCombine)
            driverLog 'initial splits are different, give up'
            makeFullQuery(newQuery)
            return
          i++

        while i < newSplitCombines.length
          splitBucketFilter = newSplitCombines[i].split.bucketFilter
          if splitBucketFilter?.type isnt 'false'
            driverLog 'final split(s) not empty, give up (but keep the current data)'
            makeFullQuery(newQuery, true)
            return
          i++

        myQuery = newQuery
        driverLog 'win, added empty split :-)'
        myOnData(myData, 'final')

      else if mySplitCombines.length is newSplitCombines.length and diff.length is 0
        # Check that the split-combines align up
        if not mySplitCombines.every((mySplitCombine, i) -> isSameSplitCombine(mySplitCombine, newSplitCombines[i]))
          myOnData(null, 'intermediate')
          driverLog 'initial splits are different, give up'
          makeFullQuery(newQuery)
          return

        { added, removed } = getPathDiff(myQuery, newQuery)
        #console.log 'added', added
        #console.log 'removed', removed

        for removePath in removed
          collapseBucket = findInData(myData, removePath, newSplitCombines)
          delete collapseBucket.splits if collapseBucket

        myQuery = newQuery

        if added.length
          throw new Error("must be 1 for now") if added.length isnt 1
          addedPath = added[0]

          attachSplit = findInData(myData, addedPath, newSplitCombines)
          throw new Error("Something went wrong") unless attachSplit

          newQueryTail = newQuery.slice(newQuery.indexOf(newSplitCombines[addedPath.length].split))
          newQueryTail[0] = _.clone(newQueryTail[0])
          delete newQueryTail[0].bucketFilter
          addQuery = [
            {
              operation: 'filter'
              type: 'and'
              filters: [newFilter].concat(
                addedPath.map((addedPart, i) -> driverUtil.filterFromSplit(newSplitCombines[i].split, addedPart))
              )
            }
          ].concat(newQueryTail)

          attachSplit.loading = true
          myOnData(myData, 'intermediate')

          transport {query: addQuery}, (err, partialData) ->
            delete attachSplit.loading

            if err
              myOnData(myData, 'final')
              driverLog 'failed to load query'
              return


            attachSplit.splits = partialData.splits
            driverUtil.parentify(myData)
            myOnData(myData, 'final')
            driverLog 'Finally a win (with addition)'
            return
        else
          myOnData(myData, 'final')
          driverLog 'Finally a win'

      else
        driverLog 'the query is too different, give up'
        makeFullQuery(newQuery)
        return

      return

    return ({query}) ->
      throw new Error("must have query") unless query
      queryChain.push(query)
      makeStep()
      return
