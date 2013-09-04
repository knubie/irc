
# TODO: store user's profile as instance variables and create 
# getter / setter methods in order to reduce db queries.
#
# TODO: move database operations to the client.

class @Idletron extends Client
  constructor: ->
    @channels = {}
    super 'localhost', 'Idletron',
      port: 6667
      userName: 'Idletron'
      password: process.env.HECTOR_KEY
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
    @on 'error', async (msg) ->
      Log.error msg

    # Log raw messages sent from the network.
    #@on 'raw', (msg) -> console.log msg

    # Sets the channel topic.
    @on 'topic', async (channel, topic, nick, message) ->
      Channels.update {name: channel}, $set: {topic}

    # Listen for incoming messages.
    @on 'message#', async (from, to, text, message) =>
      convo = ''

      # If message is a PM
      channel = Channels.find_or_create to
      for nick of channel.nicks
        if regex.nick(nick).test(text)
          convo = nick; break

      status =
        '@': 'operator'
        '': 'normal'
      # Insert a new message
      Messages.insert
        from: from
        channel: channel.name
        text: text
        createdAt: (new Date()).getTime()
        owner: 'idletron'
        convo: convo
        status: if channel.nicks? then status[channel.nicks[from]] else 'normal'
        read: true

      if /^[?](.*)$/.test text # Listen for Wolfram queries.
        query = text.replace /^[?]\s*/g, '' # Extract query.
        wolfram.request query, (answer) =>
          if answer
            @say to, answer
          else
            @say to, "I don't know."

    # Listen for channel list response and populate
    # channel collection with the results.
    @on 'channellist_item', async (data) ->
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
      if users is 1 # If Idletron is the only user left
        @part channel
      else
        # Update Channel.nicks with the nicks object sent from the network.
        Channels.update
          name: channel
        , {$set: {nicks, users}}

    @on 'kick', async (channel, nick, kicker, reason, message) =>
      Messages.insert
        owner: 'idletron'
        channel: channel
        text: "#{nick} was kicked by #{kicker}! \"#{reason}\""
        createdAt: (new Date()).getTime()
        from: 'system'
        convo: ''
        read: false

    # Send a NAMES request when users joins, parts, or changes nick.
    for event in ['join', 'part', 'nick', 'kick']
      @on event, async (channel) => @send 'NAMES', channel

    @on 'raw', async (msg) =>
      if msg.command is 'MODE'
        @send 'MODE', msg.args[0]

      if msg.command is 'rpl_channelmodeis'
        modes = msg.args[2].split('')
        modes.shift()
        Channels.update {name: msg.args[1]}, $set: {modes}

class @Bot extends Client
  constructor: ({@_id, @username}) ->
    super 'localhost', @username,
      port: 6667
      userName: @username
      password: process.env.HECTOR_KEY
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
    @on 'error', async (msg) -> Log.error msg

    # Log raw messages sent from the network.
    #@on 'raw', (msg) -> console.log msg

    # Listen for incoming messages.
    @on 'message', async (from, to, text, message) =>
      convo = ''

      # If message is a PM
      if to is @username
        # Update user's PMs object
        if Meteor.users.findOne(@_id).profile.pms?
          {pms} = Meteor.users.findOne(@_id).profile
        else pms = {}
        pms[from] = {unread: 0} unless from of pms
        # Update the User with the new PMs object.
        Meteor.users.update @_id, $set: {'profile.pms': pms}
        # Insert a new message
        Messages.insert
          from: from
          channel: from
          text: text
          createdAt: (new Date()).getTime()
          owner: @_id
          read: false

      else #Is to a channel.
        channel = Channels.find_or_create to
        for nick of channel.nicks
          if regex.nick(nick).test(text)
            convo = nick; break

        status =
          '@': 'operator'
          '': 'normal'
        # Insert a new message
        Messages.insert
          from: from
          channel: channel.name
          text: text
          createdAt: (new Date()).getTime()
          owner: @_id
          convo: convo
          status: if channel.nicks? then status[channel.nicks[from]] else 'normal'
          read: false

    # Listen for channel list response and populate
    # channel collection with the results.
    @on 'channellist_item', async (data) ->
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
        createdAt: (new Date()).getTime()
        from: 'system'
        convo: ''
        read: false
      #if nick is @username
        #Channels.find({name}).part @username

    # Send a NAMES request when users joins, parts, or changes nick.
    for event in ['join', 'part', 'nick', 'kick']
      @on event, async (channel) => @send 'NAMES', channel

    @on 'raw', async (msg) =>
      if msg.command is 'MODE'
        @send 'MODE', msg.args[0]

      if msg.command is 'rpl_channelmodeis'
        modes = msg.args[2].split('')
        modes.shift()
        Channels.update {name: msg.args[1]}, $set: {modes}

      if msg.command is 'err_passwdmismatch'
        #TODO: Notify user of error, redirect to login.
        Meteor.users.update @_id, $set: 'services.resume.loginTokens' : []

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
    check channel, validChannelName
    # Join the channel.
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
    #check channel, validChannelName
    check text, validMessageText
    # Sends text to the specified channel and inserts a new Message doc.
    super channel, text

  part: (channel) ->
    check channel, validChannelName
    super channel, async =>
      @send 'NAMES', channel

  kick: (channel, username, reason = '') ->
    @send 'KICK', channel, username, reason
      
  # Helper funciton

  user: -> Meteor.users.findOne @_id
