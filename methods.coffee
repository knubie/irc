if Meteor.isServer
  exec = Npm.require('child_process').exec

Meteor.methods
  connect: (username, _id, channels) ->
    if Meteor.isServer
      client[username] ?= new Bot {_id, username}
      client[username].connect channels
      return null

  disconnect: (username) ->
    if Meteor.isServer
      client[username].disconnect()

  join: (username, channel) ->
    console.log client
    #join = _.compose addChannel, addUserChannel, joinIRC, addJoinMessage
    #addChannel
    #addUserChannel
      #joinIRC
      #addJoinMessage
    check username, validUsername

    user = Meteor.users.findOne({username})
    if Meteor.isServer
      # Join the channel in IRC.
      if channel not of client[username]?.chans
        newChannel = Channels.find_or_create(channel)
        unless 's' in newChannel.modes or 'i' in newChannel.modes
          client[username]?.join channel, async ->
            client.idletron.join channel
    if channel not of user.profile.channels
      # Update user's channels object
      update Meteor.users, user._id
      , "profile.channels.#{channel}"
      , (channel) ->
        channel ?=
          ignore: []
          verbose: false
          unread: []
          mentions: []
          kicked: false


    return newChannel?._id or null

  part: (username, channel) ->
    check username, validUsername
    check channel, validChannelName

    #removeChannel()
      #partIRC()
      #addPartMessage()

    #TODO: create new user-channel collection.
    # This will replace embeded docs in user's 'profile.channels' field.
    # Add a collection hook when adding or remove user-channel docs
    # to join/part a channel in IRC.

    if Meteor.isServer
      # Part the from the channel
      client[username].part channel

    if ch = Channels.findOne({name: channel})
      {nicks} = ch
      # Remove user from channel's nick list.
      delete nicks[username]
      if _.isEmpty nicks # If no users left.
        Channels.remove ch._id # Remove channel.
      else
        # Update channel with new nick list
        Channels.update ch._id, $set: {nicks}

    # Remove channel from user's channel list
    update Meteor.users, Meteor.userId(), "profile.channels"
    , (channels) ->
      delete channels[channel]
      return channels
      
    return null

  say: (username, channel, message) ->
    check username, validUsername
    #check channel, validChannelName
    #TODO: maybe check if valid username/channelname
    #TODO: Do I need this method? Does this many any client that calls this method can send a 'say' from any client?
    check message, validMessageText
    if Meteor.isServer
      client[username].say channel, message
    return null

  kick: (user, channel, username, reason) ->
    if Meteor.isServer
      client[user.username].kick channel, username, reason
    return null

  invite: (user, channel, username) ->
    if Meteor.isServer
      client[user.username].invite username, channel
    return null

  mode: (user, channel, mode, arg) ->
    if Meteor.isServer
      if arg?
        client[user.username].send 'MODE', channel, mode, arg
      else
        client[user.username].send 'MODE', channel, mode
      #TODO: move this responsibility to the bot
    if mode is '-si'
      Channels.update {name: channel}, $set: {private: false}
    if mode is '+si'
      Channels.update {name: channel}, $set: {private: true}

  topic: (user, channelId, topic) ->
    channel = Channels.findOne(channelId)
    if Meteor.isServer
      client[user.username].send 'TOPIC', channel.name, topic
    if channel.nicks[user.username] is '@'
      Channels.update channelId, $set: {topic}

  send: (command, username, args...) ->
    check command, String
    if Meteor.isServer
      client[username].send command, args...

