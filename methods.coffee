if Meteor.isServer
  exec = Npm.require('child_process').exec

Meteor.methods
  remember: (username, password, _id) ->
    if Meteor.isServer
      if _id?
        #FIXME: This is very insecure. Let IRC server read from mongo directly.
        # What if username == "; rm -rf /"
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

    #join = _.compose addChannel, addUserChannel, joinIRC, addJoinMessage
    #addChannel
    #addUserChannel
      #joinIRC
      #addJoinMessage

    newChannel = Channels.find_or_create(channel)
    # Join the channel in IRC.
    if Meteor.isServer
      unless 's' in newChannel.modes or 'i' in newChannel.modes
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
        userList: false
      # Update the User with the new channels object.
      Meteor.users.update Meteor.userId(), $set: {'profile.channels': channels}

    return newChannel._id or null

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

  mode: (user, channel, mode) ->
    if Meteor.isServer
      client[user.username].send 'MODE', channel, mode
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
