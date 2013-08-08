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
    #check user, Match.ObjectIncluding(_id: String)
    newChanId = Channels.find_or_create(channel)._id

    if Meteor.isServer
      client[username]?.join channel

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

    return newChanId


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

  topic: (user, channel, topic) ->
    if Meteor.isServer
      client[user.username].send 'TOPIC', channel, topic
