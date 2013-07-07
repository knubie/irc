Fiber = Npm.require("fibers")

Meteor.startup ->
  #FIXME: Sometimes this connects multiple times.
  #users = Meteor.users.find {}
  #users.forEach (user) -> connect user

clients = {}

join = (user, channel) ->
  if /^[#](.*)$/.test channel.name
    clients[user._id].join channel.name

connect = (user) ->
  # Set user status to connecting.
  Meteor.users.update user._id, $set: {'profile.connecting': true}

  # Create new IRC instance.
  clients[user._id] = new IRC.Client 'irc.choopa.net', user.username,
    autoConnect: false

  clients[user._id].on 'error', (msg) -> console.log msg

  clients[user._id].connect Meteor.bindEnvironment ->
    console.log 'connected.'
    # Set user status to connected.
    Meteor.users.update user._id, $set: {'profile.connecting': false}
    # Listen for messages and create new Messages doc for each one.
    clients[user._id].on 'message', Meteor.bindEnvironment (from, to, text, message) ->
      if text.match ".*#{user.username}.*"
        type = 'mention'
      else
        type = 'normal'
      Messages.insert
        from: from
        to: to
        text: text
        time: new Date
        owner: user._id
        type: type
    , (err) -> console.log err
    # Listen for when the client requests names from a channel
    # and log them to corresponding the channel document.
    clients[user._id].on 'names', Meteor.bindEnvironment (channel,nicks) ->
      nicksArray = for nick, status of nicks
        nick
      Channels.update
        name: channel
        owner: user._id
      , {$set: {'nicks': nicksArray}}
    , (err) -> console.log err
    # Listen for when users join or part a channel.
    # Request names for that channel from the server.
    # When names are request the names listener will be called
    # which sets the name to the corresponding channel doc.
    clients[user._id].on "join", Meteor.bindEnvironment (chan) ->
      clients[user._id].send 'NAMES', chan
    , (err) -> console.log err
    clients[user._id].on "part", Meteor.bindEnvironment (chan) ->
      clients[user._id].send 'NAMES', chan
    , (err) -> console.log err
    # Join all channels subscribed to by user.
    channels = Channels.find owner: user._id
    channels.forEach (channel) -> join user, channel
  , (err) -> console.log err

Meteor.methods
  newClient: (user) ->
    connect user
  join: (user, channel) ->
    join user, channel
  part: (user, channel) ->
    clients[user._id].part channel
  say: (user, channel, message) ->
    clients[user._id].say channel, message
    Messages.insert
      from: user.username
      to: channel
      text: message
      time: new Date
      owner: user._id
      type: 'self'

Meteor.publish 'channels', ->
  Channels.find {owner: @userId}

Meteor.publish 'messages', (to, limit) ->
  if to is 'all'
    Messages.find {owner: @userId}, {limit, sort:{time: -1}}
  else
    Messages.find {owner: @userId, to}, {limit, sort:{time: -1}}
    
