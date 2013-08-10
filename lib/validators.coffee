validUsername = Match.Where (u) ->
  check u, String
  /^[^\W]*$/.test u and u.length > 0

validChannelName = Match.Where (c) ->
  check c, String
  c.length > 1
  # Starts with #
  #must begin with a letter
  #limit size
