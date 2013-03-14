arraySubclass = if [].__proto__
    # Until ECMAScript supports array subclassing, prototype injection works well.
    (array, prototype) ->
      array.__proto__ = prototype
      return array
  else
    # And if your browser doesn't support __proto__, we'll use direct extension.
    (array, prototype) ->
      array[property] = prototype[property] for property in prototype
      return array


flatten = (ar) -> Array::concat.apply([], ar)