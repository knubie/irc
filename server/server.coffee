#Fiber = Npm.require("fibers")

Meteor.startup ->
  Meteor.call 'connect', user for user in Meteor.users.find().fetch()

async = (cb) -> Meteor.bindEnvironment cb, (err) -> console.log err

client = {}

class Client
  constructor: ({@_id, @username}) ->
    # Create a new IRC Client instance.
    @client = new IRC.Client 'irc.freenode.net', @username,
      userName: @username
      realName: 'N/A'
      autoConnect: false

    # Log errors sent from the network.
    @client.on 'error', (msg) -> console.log msg

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

    # Listen for 'names' requests.
    @client.on 'names', async (channel, nicks) =>
      # Update Channel.nicks with the nicks object sent from the network.
      Channels.update
        name: channel
        owner: @_id
      , {$set: {nicks}}

    # Send a NAMES request when users joins, parts, or changes nick.
    @client.on "join", async (channel) => @client.send 'NAMES', channel
    @client.on "part", async (channel) => @client.send 'NAMES', channel
    @client.on "nick", async (channel) => @client.send 'NAMES', channel

  connect: ->
    # Connect to the IRC network.
    console.log 'connecting..'
    @client.connect async =>
      console.log 'connected'
      # Set connecting status to false.
      Meteor.users.update @_id, $set: {'profile.connecting': false}
      # Join subscribed channels.
      @join channel.name for channel in Channels.find(owner: @_id).fetch()

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

Meteor.methods
  connect: (user) ->
    check user, Match.ObjectIncluding({_id: String, username: String})
    Meteor.users.update user._id, $set: {'profile.connecting': true}
    client[user._id] ?= new Client user
    client[user._id].connect()

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

Meteor.publish 'users', ->
  Meteor.users.find()

Meteor.publish 'channels', ->
  Channels.find {owner: @userId}

Meteor.publish 'messages', (channel, limit) ->
  if channel is 'all'
    Messages.find {owner: @userId}, {limit, sort:{time: -1}}
  else
    Messages.find {owner: @userId, to: channel}, {limit, sort:{time: -1}}
