exports.isInstanceOf = (facetChild, facetParent) ->
  parentName = facetParent.name
  pointer = facetChild
  while pointer?
    return true if pointer.constructor.name is parentName
    pointer = pointer.constructor.__super__
  return false
