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

    # Listen for channel list response and populate
    # channel collection with the results.
    @on 'channellist_item', async (data) ->
      {name, users, topic} = data
      channel = Channels.find_or_create name
      Channels.update channel, $set: {users, topic}

    #@on 'join', async (channel, nick, message) =>
      #unless Channels.findOne({name: channel}).nicks[nick]? \
      #or nick is @username \
      #or nick is 'Idletron'
        #Messages.insert
          #owner: @_id
          #channel: channel
          #text: "#{nick} has joined the channel."
          #createdAt: (new Date()).getTime()
          #from: 'system'
          #convo: ''
          #read: false

    # Listen for incoming messages.
    @on 'message', async (from, to, text, message) =>
      if not to.isChannel() and from isnt @username
        #FIXME: this won't work.
        unless Meteor.users.findOne({username: from})
          # Server sends message to IRC before insert.
          Messages.insert
            to: to
            from: from
            text: text
            mobile: false
            createdAt: new Date()
            owner: 'server'

    @on 'kick', async (channel, nick, kicker, reason, message) =>
      if nick is @username
        update Meteor.users, @_id, "profile.channels"
        , (channels) ->
          channels[channel].kicked = true
          return channels

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

    # Listen for incoming messages.
    #@on 'message#', async (from, to, text, message) =>

  connect: (channels) ->
    # Connect to the IRC network.
    super async =>
      console.log "connected #{@username}"
      Meteor.users.update @_id, $set: {'profile.connection': on}
      # Set connecting status to on.
      if channels?
        for channel in channels
          Meteor.call 'join', @username, channel
      # Join subscribed channels.
      #if {channels} = @user()?.profile
        #@join channel for channel of channels

  disconnect: ->
    super async =>
      Meteor.users.update @_id, $set: {'profile.connection': off}

  join: (channel, cb) ->
    check channel, validChannelName
    @channels = @channels or []
    # Join the channel.
    if cb?
      super channel, async(cb) #TODO: double check that join was successful
    else
      super channel

    # Request channel modes
    @send 'MODE', channel

    @channels.push(channel) unless channel in @channels

  say: (target, text) ->
    #check channel, validChannelName
    check text, validMessageText
    super target, text

  part: (channel) ->
    check channel, validChannelName
    super channel, async =>
      @send 'NAMES', channel
      @channels.splice(@channels.indexOf(channel), 1)

  kick: (channel, username, reason = '') ->
    @send 'KICK', channel, username, reason

  invite: (username, channel) ->
    @send 'INVITE', username, channel
      
  # Helper funciton

  user: -> Meteor.users.findOne @_id
