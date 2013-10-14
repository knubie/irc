@update = (collection, query, field, update) ->
  # Set up this object to pass in to the mongo update method.
  $set = {}

  # Create the $set object for mongo's update method by passing
  # the doc's 'field' to the 'update' argument.
  $set[field] = _.compose(update, _.reduce) field.split('.')
  , (memo, accessor) ->
    memo[accessor] # Get field from the doc.
  , collection.findOne(query)

  # Update the mongo collection.
  collection.update query, {$set}
