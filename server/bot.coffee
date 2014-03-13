class @Bot extends Client
  constructor: ({@_id, @username}) ->
    super 'localhost', @username,
      port: 6667
      userName: @username
      password: process.env.HECTOR_KEY
      realName: 'N/A'
      autoConnect: no
      autoRejoin: no

    # Set max listeners to unlimited.
    @setMaxListeners 0
    # Remove all previous listeners just in case.
    @removeAllListeners ['error', 'message']

    # Log errors sent from the network.
    @on 'error', async (msg) -> Log.error msg

    # Log raw messages sent from the network.
    #@on 'raw', (msg) -> console.log msg

    # Listen for incoming messages.
    @on 'message', async (from, to, text, message) =>
      if to is @username
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
    # Join the channel.
    if cb?
      super channel, async(cb) #TODO: double check that join was successful
    else
      super channel

    # Request channel modes
    @send 'MODE', channel

  say: (target, text) ->
    #check channel, validChannelName
    check text, validMessageText
    super target, text

  part: (channel) ->
    check channel, validChannelName
    super channel, async =>
      @send 'NAMES', channel

  kick: (channel, username, reason = '') ->
    @send 'KICK', channel, username, reason

  invite: (username, channel) ->
    @send 'INVITE', username, channel
      
  # Helper funciton

  user: -> Meteor.users.findOne @_id
