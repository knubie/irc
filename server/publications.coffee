Meteor.publish 'users', ->
  #Todo: limit to current channel
  Meteor.users.find({}, fields: emails: 0, services: 0)
  #Meteor.users.find().forEach (user) =>
    #user.avatar = Gravatar.imageUrl user.emails[0].address
    #delete user.emails
    #delete user.services
    #@added 'users', user._id, user

Meteor.publish 'publicChannels', ->
  #TODO: Add limit and pagination
  Channels.find modes: $nin: ['s', 'i']

Meteor.publish 'joinedChannels', ->
  query = {}
  username = Meteor.users.findOne(@userId)?.username
  query["nicks.#{username}"] = {$exists: true}
  Channels.find query

Meteor.publish 'allMessages', (userId, limit) ->
  channels = (channel for channel of Meteor.users.findOne(userId).profile.channels)
  handle = Messages.find({channel: {$in: channels}}, {limit: limit, sort: createdAt: -1})
  .observeChanges
    added: (id, fields) =>
      @added 'messages', id, fields

  @ready()
  @onStop -> handle.stop()

Meteor.publish 'messages', (channel, limit) ->
  # If subscribing to all channels, the channel
  # argument will be an array of channels.
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
  handle = Messages.find({channel, convos: $in: [user.username]}
  , {limit, sort:{createdAt: -1}})
  .observeChanges
    added: (id, fields) =>
      @added 'messages', id, fields

  @ready()
  @onStop -> handle.stop()
