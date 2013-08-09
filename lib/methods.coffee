if Meteor.isServer
  exec = Npm.require('child_process').exec

Meteor.methods
  remember: (username, password, _id) ->
    if Meteor.isServer
      if _id?
        exec "cd ~/Development/hector/idletron.hect; hector identity remember #{username} #{password}", async ->
          console.log 'remember succeeded'
          Meteor.call 'connect', username, password, _id
      return null

  connect: (username, password, _id) ->
    if Meteor.isServer
      client[username] ?= new Client {_id, username, password}
      client[username].connect()

  join: (username, channel) ->
    newChannel = Channels.find_or_create(channel)
    # Join the channel in IRC.
    if Meteor.isServer
      client[username]?.join channel
    # Update user's channels object
    {channels} = Meteor.user().profile
    # Add the new channel if it's not there already.
    unless channel of channels
      channels[channel] =
        ignore: []
        verbose: false
        unread: 0
        mentions: 0
    # Update the User with the new channels object.
    Meteor.users.update Meteor.userId(), $set: {'profile.channels': channels}

    return newChanId._id

  part: (user, channel) ->
    if Meteor.isServer
      client[user.username].part channel

    Channels.findOne({name: channel}).part user.username
    {channels} = Meteor.user().profile
    delete channels[channel]
    Meteor.users.update Meteor.userId, $set: {'profile.channels': channels}
    return null

  say: (user, channel, message) ->
    if Meteor.isServer
      client[user.username].say channel, message
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
