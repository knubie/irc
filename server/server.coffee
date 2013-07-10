Fiber = Npm.require("fibers")

isChannel = (text) ->
  /^[#](.*)$/.test text

Meteor.startup ->
  #FIXME: Sometimes this connects multiple times.
  #users = Meteor.users.find {}
  #users.forEach (user) -> connect user

clients = {}

join = (user, channel) ->
  if /^[#](.*)$/.test channel
    clients[user._id].join channel

connect = (user) ->
  # Set user status to connecting.
  Meteor.users.update user._id, $set: {'profile.connecting': true}

  # Create new IRC instance.
  clients[user._id] = new IRC.Client 'irc.choopa.net', user.username,
    autoConnect: false

  clients[user._id].on 'error', (msg) -> console.log msg

  # Connect the client to the server.
  clients[user._id].connect Meteor.bindEnvironment ->
    console.log 'connected.'
    # Set user status to connected.
    Meteor.users.update user._id, $set: {'profile.connecting': false}
    # Listen for messages and create new Messages doc for each one.
    clients[user._id].on 'message', Meteor.bindEnvironment (from, to, text, message) ->
      type = 'normal'
      # Rearrange some stuff to make messages
      # show up where they're supposed to.
      mentionRegex = new RegExp ".*#{user.username}.*"
      if mentionRegex.test text
        type = 'mention'
        Channels.update {owner: user._id, name: to}, {$inc: {notifications: 1}}
        Channels.update {owner: user._id, name: 'all'}, {$inc: {notifications: 1}}
      # If receiving a PM
      if to is user.username
        # Check if "from" is in channel list, if not add it.
        onList = false
        channels = Channels.find owner: user._id
        channels.forEach (channel) -> onList = true if from is channel.name
        unless onList
          Channels.insert
            owner: user._id
            name: from
            nicks: [from, to]
            notifications: 1
        else
          Channels.update {owner: user._id, name: from}, {$inc: {notifications: 1}}
        Channels.update {owner: user._id, name: 'all'}, {$inc: {notifications: 1}}
        # Channel list displays "to" not "from"
        # (to is usually channel name)
        to = from
      Messages.insert
        from: from
        to: to
        text: text
        type: type
        time: new Date
        owner: user._id
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
    clients[user._id].on "join", Meteor.bindEnvironment (chan) ->
      # Request names for that channel from the server.
      # When names are requested the names listener will be called
      # which sets the name to the corresponding channel's nicks array.
      clients[user._id].send 'NAMES', chan
    , (err) -> console.log err
    clients[user._id].on "part", Meteor.bindEnvironment (chan) ->
      clients[user._id].send 'NAMES', chan
    , (err) -> console.log err
    # Join all channels subscribed to by user.
    channels = Channels.find owner: user._id
    channels.forEach (channel) -> join user, channel.name
  , (err) -> console.log err

Meteor.methods
  newClient: (user) ->
    connect user
  join: (user, name) ->
    owner = user._id
    # If it's a channel, set an empty array and let the NAMES req populate it.
    # If it's a PM, set the nicks array to the current user and sender.
    nicks = if /^[#](.*)$/.test name then [] else [user.username, name]
    Channels.insert {owner, name, nicks, notifications: 0}
    join user, name

  part: (user, channel) ->
    clients[user._id].part channel if /^[#](.*)$/.test channel
    Channels.remove {owner: user._id, name: channel}
    #Messages.remove {owner: user._id, to: channel}

  say: (user, channel, message) ->
    clients[user._id].say channel, message
    Messages.insert
      from: user.username
      to: channel #TODO: perhaps change this to owner: channel._id
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
    
