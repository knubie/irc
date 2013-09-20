if Meteor.isServer
  exec = Npm.require('child_process').exec

Meteor.methods
  remember: (username, password, _id) ->
    if Meteor.isServer
      if _id?
        #FIXME: What if username = "; rm -rf /"
        exec "cd $HECTOR_PATH; hector identity remember #{username} #{password}", async ->
          Meteor.call 'connect', username, _id
      return null

  connect: (username, _id) ->
    if Meteor.isServer
      client[username] ?= new Bot {_id, username}
      if Meteor.users.findOne(_id)?.profile.connection is off
        client[username].connect()

  disconnect: (username) ->
    if Meteor.isServer
      client[username].disconnect()

  join: (username, channel) ->
    check username, validUsername
    check channel, validChannelName
    newChannel = Channels.find_or_create(channel)
    # Join the channel in IRC.
    if Meteor.isServer
      client[username]?.join channel
      client.idletron.join channel
    # Update user's channels object
    {channels} = Meteor.user().profile
    # Add the new channel if it's not there already.
    unless channel of channels
      channels[channel] =
        ignore: []
        verbose: false
        unread: []
        mentions: []
    # Update the User with the new channels object.
    Meteor.users.update Meteor.userId(), $set: {'profile.channels': channels}

    return newChannel._id or null

  part: (username, channel) ->
    check username, validUsername
    check channel, validChannelName
    if Meteor.isServer
      client[username].part channel

    ch = Channels.findOne({name: channel})
    if ch?
      {nicks} = ch
      delete nicks[username]
      if _.isEmpty nicks
        Channels.remove ch._id
      else
        Channels.update ch._id, $set: {nicks}
    #Channels.findOne({name: channel}).part username
      #part: (nick) ->
        #{nicks} = @
        #delete nicks[nick]
        #if _.isEmpty nicks
          #Channels.remove @_id
        #else
          #Channels.update @_id, $set: {nicks}
    {channels} = Meteor.user().profile
    delete channels[channel]
    Meteor.users.update Meteor.userId(), $set: {'profile.channels': channels}
    return null

  say: (username, channel, message) ->
    check username, validUsername
    #check channel, validChannelName
    #TODO: maybe check if valid username/channelname
    check message, validMessageText
    if Meteor.isServer
      client[username].say channel, message
    return null

  kick: (user, channel, username, reason) ->
    if Meteor.isServer
      client[user.username].kick channel, username, reason
    return null

  mode: (user, channel, mode) ->
    if Meteor.isServer
      client[user.username].send 'MODE', channel, mode

  topic: (user, channelId, topic) ->
    channel = Channels.findOne(channelId)
    if Meteor.isServer
      client[user.username].send 'TOPIC', channel.name, topic
    if channel.nicks[user.username] is '@'
      Channels.update channelId, $set: {topic}

  date: -> (new Date()).getTime()
