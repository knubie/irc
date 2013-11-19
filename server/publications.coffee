Meteor.publish 'users', -> Meteor.users.find()
Meteor.publish 'publicChannels', ->
  #Channels.find {private: {$ne: true}}
  Channels.find modes: $nin: ['s', 'i']

Meteor.publish 'joinedChannels', ->
  query = {}
  username = Meteor.users.findOne(@userId).username
  query["nicks.#{username}"] = {$exists: true}
  Channels.find query

Meteor.publish 'messages', (channel, limit) ->
  # If subscribing to all channels, the channel argument will be an
  # array of channels.
  if isArray channel
    selector = {$in: channel}
  else # Otherwise just subscribe to a single channel.
    selector = channel
  handle = Messages.find({channel: selector}, {limit: limit, sort: createdAt: -1})
  .observeChanges
    added: (id, fields) =>
      @added 'messages', id, fields

  @ready()
  @onStop -> handle.stop()

Meteor.publish 'privateMessages', (from, limit) ->
  {username} = Meteor.users.findOne(@userId)
  selector =
    $or: [
      {to:username, from},
      {from:username, to:from}
    ]
  handle = Messages.find(selector, {limit, sort: createdAt: -1})
  .observeChanges
    added: (id, fields) =>
      @added 'messages', id, fields 

  @ready()
  @onStop -> handle.stop()

Meteor.publish 'mentions', (channel, limit) ->
  user = Meteor.users.findOne(@userId)
  handle = Messages.find({chanell, convos: $in: [user.username]}
  , {limit, sort:{createdAt: -1}})
  .observeChanges
    added: (id, fields) =>
      @added 'messages', id, fields 

  @ready()
  @onStop -> handle.stop()
