@validUsername = Match.Where (u) ->
  check u, String
  /^[^\W]*$/.test(u) and u.length > 0

@validChannelName = Match.Where (c) ->
  check c, String
  /^#[^\W]*$/.test(c) and c.length > 0 and c.length < 51

@validMessageText = Match.Where (m) ->
  check m, String
  m.length > 0 and m.length < 512
