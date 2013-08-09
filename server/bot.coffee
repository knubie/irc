
# TODO: store user's profile as instance variables and create 
# getter / setter methods in order to reduce db queries.
#
# TODO: move database operations to the client.

class @Client extends IRC.Client
  constructor: ({@_id, @username, @password}) ->
    super 'localhost', @username,
      port: 6667
      userName: @username
      password: @password
      realName: 'N/A'
      autoConnect: no
      autoRejoin: no

    # Remove all previous listeners just in case.
    @removeAllListeners [
      'error'
      'message'
      'names'
      'join'
      'part'
      'nick'
    ]

    # Log errors sent from the network.
    @on 'error', (msg) -> console.log msg

    # Log raw messages sent from the network.
    #@on 'raw', (msg) -> console.log msg

    # Sets the channel topic.
    @on 'topic', async (channel, topic, nick, message) ->
      Channels.update {name: channel}, $set: {topic}

    # Listen for incoming messages.
    @on 'message', async (from, to, text, message) =>

      convo = ''

      if to is @username
        if not Channels.findOne(name: from)
          channelId = Meteor.call 'join', @username, from
          channel = Channels.findOne channelId
        else
          channel = Channels.find_or_create from
      else
        channel = Channels.find_or_create to

      if to.isChannel()
        for nick of channel.nicks
          if regex.nick(nick).test(text)
            convo = nick; break
      else
        nicks = {}
        nicks[to] = ''
        nicks[from] = ''
        Channels.update channel._id, $set: {nicks}

      # Insert a new message
      Messages.insert
        from: from
        channel: channel.name
        text: text
        time: new Date
        owner: @_id
        convo: convo

    # Listen for channel list response and populate
    # channel collection with the results.
    @on 'channellist_item', (data) ->
      {name, users, topic} = data
      channel = Channels.find_or_create name
      Channels.update channel, $set: {users, topic}

    # Listen for 'names' requests.
    @on 'names', async (channel, nicks_in) =>
      #TODO: Either add rpl_isupport to hector, or remove from node-irc
      nicks = {}
      for nick, status of nicks_in
        match = nick.match(/^(.)(.*)$/)
        if match
          if match[1] is '@'
            nicks[match[2]] = match[1]
          else
            nicks[nick] = ''
      # Count the number of nicks in the nicks_in object
      users = (user for user of nicks).length
      # Update Channel.nicks with the nicks object sent from the network.
      console.log 'got names req, updating channel'
      console.log Channels.findOne(name: channel)
      Channels.update
        name: channel
      , {$set: {nicks, users}}

    @on 'kick', async (channel, nick, kicker, reason, message) =>
      Messages.insert
        owner: @_id
        channel: channel
        text: "#{nick} was kicked by #{kicker}! \"#{reason}\""
        time: new Date
        from: 'system'
        convo: ''
      if nick is @username
        Channels.find({name}).part @username
        console.log "You have been kicked from #{channel}."
        console.log "Reason: #{reason}"

    # Send a NAMES request when users joins, parts, or changes nick.
    for event in ['join', 'part', 'nick', 'kick']
      @on event, async (channel) => @send 'NAMES', channel

    @on 'raw', async (msg) =>
      if msg.command is 'MODE'
        console.log 'got MODE'
        @send 'MODE', msg.args[0]

      if msg.command is 'rpl_channelmodeis'
        console.log 'got rpl_channelmodeis'
        modes = msg.args[2].split('')
        modes.shift()
        Channels.update {name: msg.args[1]}, $set: {modes}

    #@on 'MODE', (msg) =>
      #console.log 'got MODE'
      #@send 'MODE', msg.args[0]
    ## args: [ '#test', '+s' ]

    #@on 'rpl_channelmodeis', (msg) ->
      #console.log 'got rpl_channelmodeis'
      #Channels.update {name: args[1]}
      #, $set: {modes: msg.args[2].split('').shift()}

      #console.log msg.args[2].split('').shift()
      # args: [ 'bill', '#test', '+s' ]

    #@on 'raw', (msg) ->
      #if msg.rawCommand is 'RPL_CHANNELMODEIS'

      #console.log msg

  connect: ->
    # Connect to the IRC network.
    super async =>
      # Set connecting status to on.
      Meteor.users.update @_id, $set: {'profile.connection': on}
      # Join subscribed channels.
      if {channels} = @user()?.profile
        @join channel for channel of channels

  disconnect: ->
    super async =>
      Meteor.users.update @_id, $set: {'profile.connection': off}

  join: (channel) ->
    # Join the channel.
    if channel.isChannel()
      super channel #TODO: double check that join was successful

      # Request channel modes
      @send 'MODE', channel

    #else # channel is actually a nick
      #nicks[name] = '' # Add nick to nicks object.
      ## Update channel with new nicks.
      #Channels.update
        #name: name
        #owner: @_id
      #, {$set: {nicks}}

  say: (channel, text) ->
    check channel, String
    check text, String
    # Sends text to the specified channel and inserts a new Message doc.
    super channel, text

    convo = ''
    for nick of Channels.findOne(name: channel).nicks
      if regex.nick(nick).test(text)
        convo = nick
        break

    Messages.insert
      from: @username
      channel: channel
      text: text
      time: new Date
      owner: @_id
      convo: convo

  part: (name) ->
    # Leave the channel if it is in fact a channel (ie. not a nick)
    super name if name.isChannel()

  kick: (channel, username, reason = '') ->
    @send 'KICK', channel, username, reason
      
  # Helper funciton

  user: -> Meteor.users.findOne @_id
