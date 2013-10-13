@update = (collection, query, field, update) ->
  # Set up this object to pass in to the mongo update method.
  $set = {}

  # Access the field we want to update based on the 'field' argument.
  # e.g. field = "profile.channels.#test.ignore"
  iteratee = _.reduce field.split('.'), (memo, accessor) ->
    memo[accessor]
  , collection.findOne(query)

  # Creat the final $set object by calling our iterator function
  $set[field] = update(iteratee)

  # Update the mongo collection.
  collection.update query, {$set}
