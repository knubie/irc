
# TODO: store user's profile as instance variables and create 
# getter / setter methods in order to reduce db queries.

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
      # Insert a new message
      Messages.insert
        from: from
        channel: if to is @username then from else to
        text: text
        time: new Date
        owner: @_id

      # Create new Channel if message is a PM.
      @join from if to is @username

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
    Channels.find_or_create channel
    # Join the channel.
    if channel.isChannel()
      super channel, async =>
        {channels} = @user().profile
        # Add the new channel if it's not there already.
        unless channel of channels
          channels[channel] =
            ignore: []
            verbose: false
            unread: 0
            mentions: 0
        # Update the User with the new channels object.
        Meteor.users.update @_id, $set: {'profile.channels': channels}
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
    Messages.insert
      from: @username
      channel: channel
      text: text
      time: new Date
      owner: @_id

  part: (name) ->
    check name, String
    # Leave the channel if it is in fact a channel (ie. not a nick)
    Channels.findOne({name}).part @username
    super name if name.isChannel()
    {channels} = @user().profile
    delete channels[name]
    Meteor.users.update @_id, $set: {channels}

  kick: (channel, username, reason) ->
    reason = reason or ''
    @send 'KICK', channel, username, reason

  mode: (channel, mode) -> @send 'MODE', channel, mode
      
  # Helper funciton

  user: -> Meteor.users.findOne @_id
