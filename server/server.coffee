spawn = Npm.require('child_process').spawn
exec = Npm.require('child_process').exec
Fiber = Npm.require("fibers")
Meteor.startup ->
  #Meteor.call 'connect', user for user in Meteor.users.find().fetch()

async = (cb) -> Meteor.bindEnvironment cb, (err) -> console.log err

client = {}

class Client
  constructor: ({@_id, @username}) ->
    # Create a new IRC Client instance.
    @client = new IRC.Client 'localhost', @username,
      port: 6767
      userName: @username
      realName: 'N/A'
      autoConnect: no
      autoRejoin: no

    # Remove all previous listeners just in case.
    @client.removeAllListeners [
      'error'
      'message'
      'names'
      'join'
      'part'
      'nick'
    ]

    # Log errors sent from the network.
    @client.on 'error', (msg) -> console.log msg

    # Log raw messages sent from the network.
    @client.on 'raw', (msg) -> console.log msg

    # Listen for incoming messages.
    @client.on 'message', async (from, to, text, message) =>
      # Insert a new message
      Messages.insert
        from: from
        channel: if to is @username then from else to
        text: text
        time: new Date
        owner: @_id

      # Create new Channel if message is a PM.
      @join from if to is @username

    # Handle various actions by the network.
    @client.on 'raw', async (msg) =>
      if msg.command is 'rpl_list'
        Channels.insert
          owner: 'network'
          name: msg.args[1]
          count: msg.args[2]
          topic: msg.args[3]

    # Listen for 'names' requests.
    @client.on 'names', async (channel, nicks_in) =>
      #TODO: Either add rpl_isupport to hector, or remove from node-irc
      nicks = {}
      for nick, status of nicks_in
        match = nick.match(/^(.)(.*)$/)
        if match
          if match[1] is '@'
            nicks[match[2]] = match[1]
          else
            nicks[nick] = ''
      # Update Channel.nicks with the nicks object sent from the network.
      Channels.update
        name: channel
        owner: @_id
      , {$set: {nicks}}

    @client.on 'kick', async (channel, nick, kicker, reason, message) =>
      Messages.insert
        owner: @_id
        channel: channel
        text: "#{nick} was kicked by #{kicker}! \"#{reason}\""
        time: new Date
        from: 'system'
      if nick is @username
        Channels.remove {owner: @_id, name: channel}
        console.log "You have been kicked from #{channel}."
        console.log "Reason: #{reason}"

    # Send a NAMES request when users joins, parts, or changes nick.
    for event in ['join', 'part', 'nick', 'kick']
      @client.on event, async (channel) => @client.send 'NAMES', channel

  connect: (password) ->
    # Connect to the IRC network.
    console.log "connecting.."
    @client.connect async =>
      console.log 'connected'
      # Set connecting status to false.
      Meteor.users.update @_id, $set: {'profile.connecting': false}
      # Join subscribed channels.
      @join channel.name for channel in Channels.find(owner: @_id).fetch()
      @client.list()
    @client.send 'PASS', password

  join: (channel) ->
    check channel, String
    # Create a base nicks object.
    nicks = {}
    nicks[@username] = ''

    if channel.isChannel() # channel begins with '#'
      @client.join channel
    else # channel is actually a nick
      nicks[channel] = '' # Add nick to nicks object.
      # Update channel with new nicks.
      Channels.update
        name: channel
        owner: @_id
      , {$set: {nicks}}

  say: (channel, text) ->
    check channel, String
    check text, String
    # Sends text to the specified channel and inserts a new Message doc.
    @client.say channel, text
    Messages.insert
      from: @username
      channel: channel
      text: text
      time: new Date
      owner: @_id

  part: (channel) ->
    check channel, String
    # Leave the channel if it is in fact a channel (ie. not a nick)
    @client.part channel if channel.isChannel
    # Remove the corresponding Channel doc.
    Channels.remove {owner: @_id, name: channel}
    #Messages.remove {owner: user._id, to: channel}

  kick: (channel, username, reason) ->
    reason = reason or ''
    @client.send 'KICK', channel, username, reason

Meteor.methods
  connect: (user, password) ->
    check user, Match.ObjectIncluding({_id: String, username: String})
    Meteor.users.update user._id, $set: {'profile.connecting': true}
    unless client[user._id]?
      client[user._id] = new Client user
      client[user._id].connect(password)

  join: (user, channel) ->
    check user, Match.ObjectIncluding(_id: String)
    client[user._id].join channel

  part: (user, channel) ->
    check user, Match.ObjectIncluding(_id: String)
    check channel, String
    client[user._id].part channel

  say: (user, channel, message) ->
    check user, Match.ObjectIncluding(_id: String)
    check channel, String
    check message, String
    client[user._id].say channel, message

  remember: (username, password, email) ->
    exec "cd ~/Development/hector/myserver.hect; hector identity remember #{username} #{password}", ->
      Fiber(->
        newUser = Accounts.createUser
          username: username
          email: email
          password: password
          profile:
            connecting: true
        Channels.insert
          owner: newUser
          name: 'all'
        Meteor.call 'connect', {_id: newUser, username}, password
        console.log 'remembered'
      ).run()

  kick: (user, channel, username, reason) ->
    client[user._id].kick channel, username, reason

Meteor.publish 'users', ->
  Meteor.users.find()

Meteor.publish 'channels', ->
  Channels.find {$or: [{owner: @userId}, {owner: 'network'}]}

Meteor.publish 'messages', (channel, limit) ->
  if channel is 'all'
    Messages.find {owner: @userId}, {limit, sort:{time: -1}}
  else
    Messages.find {owner: @userId, to: channel}, {limit, sort:{time: -1}}
