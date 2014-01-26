class @Idletron extends Client
  constructor: (@nick) ->
    @channels = {}
    super 'localhost', @nick,
      port: 6667
      userName: @nick
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
      #FIXME: this won't work.
      unless Meteor.users.findOne({username: from})
        # Server sends message to IRC before insert.
        Messages.insert
          channel: to
          text: text
          mobile: false
          createdAt: new Date()
          from: from
          owner: 'server'

      if /^[?](.*)$/.test text # Listen for Wolfram queries.
        @say to, "I don't work yet."
        Messages.insert
          channel: to
          text: "I don't work yet."
          mobile: false
          createdAt: new Date()
          from: 'Idletron'
          owner: 'server'
        #query = text.replace /^[?]\s*/g, '' # Extract query.
        #wolfram.request query, (answer) =>
          #if answer
            #@say to, answer
            #Messages.insert
              #channel: to
              #text: answer
              #mobile: false
              #createdAt: new Date()
              #from: 'Idletron'
              #owner: 'server'
          #else
            #@say to, "I don't know."
            #Messages.insert
              #channel: to
              #text: "I don't know."
              #mobile: false
              #createdAt: new Date()
              #from: 'Idletron'
              #owner: 'server'

    @on 'action', async (from, to, text, message) =>
      #FIXME: this won't work.
      unless Meteor.users.findOne({username: from})
        Messages.insert
          channel: to
          text: "#{from} #{text}"
          mobile: false
          createdAt: new Date()
          from: 'system'
          owner: 'server'

    # Listen for channel list response and populate
    # channel collection with the results.
    @on 'channellist_item', async (data) ->
      {name, users, topic} = data
      channel = Channels.find_or_create name
      Channels.update channel, $set: {users, topic}

    # Listen for 'names' requests.
    #@on 'names', async (channel, nicks_in) =>
      ##TODO: Either add rpl_isupport to hector, or remove from node-irc
      #console.log "names==========#{channel}"
      #console.log nicks_in
      #nicks = {}
      #for nick, status of nicks_in
        #match = nick.match(/^(.)(.*)$/)
        #if match
          #if match[1] is '@'
            #nicks[match[2]] = match[1]
          #else
            #nicks[nick] = ''
      ## Count the number of nicks in the nicks_in object
      #users = (user for user of nicks).length
      ## Update Channel.nicks with the nicks object sent from the network.
      #Channels.update
        #name: channel
      #, {$set: {nicks, users}}

    @on 'kick', async (channel, nick, kicker, reason, message) =>
      text = "#{nick} was kicked by #{kicker}."
      text = text + " \"#{reason}\"" if reason
      Messages.insert
        owner: 'server'
        channel: channel
        text: text
        createdAt: new Date()
        from: 'system'

    # Send a NAMES request when users joins, parts, or changes nick.
    for event in ['join', 'part', 'nick', 'kick', 'quit']
      @on event, async (channel) => @send 'NAMES', channel

    @on 'part', async (channel, nick, reason, message) =>
      ch = Channels.findOne({name: channel})
      if ch?
        if nick of ch.nicks
          if (nick for nick of ch.nicks).length is 2
            @part channel
            Channels.remove ch._id
        else
          if (nick for nick of ch.nicks).length is 1
            @part channel
            Channels.remove ch._id

    @on 'quit', async (nick, reason, channels, message) =>
      for channel in channels
        ch = Channels.findOne({name: channel})
        if ch?
          if nick of ch.nicks
            if (nick for nick of ch.nicks).length is 2
              @part channel
              Channels.remove ch._id
          else
            if (nick for nick of ch.nicks).length is 1
              @part channel
              Channels.remove ch._id

    @on 'raw', async (msg) =>
      if msg.command is 'MODE'
        @send 'MODE', msg.args[0]

      if msg.command is 'rpl_channelmodeis'
        modes = msg.args[2].split('')
        modes.shift()
        Channels.update {name: msg.args[1]}, $set: {modes}

      if msg.command is 'rpl_namreply'
        channel = msg.args[2]
        nicks_in = msg.args[3].split ' '
        #TODO: Either add rpl_isupport to hector, or remove from node-irc
        nicks = {}
        for nick in nicks_in
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

    @on '+mode', async (channel, from, mode, argument, message) =>
      if mode is 'o'
        update Channels, {name: channel}
        , "nicks.#{argument}"
        , (user) -> '@'

    @on '-mode', async (channel, from, mode, argument, message) =>
      if mode is 'o'
        update Channels, {name: channel}
        , "nicks.#{argument}"
        , (user) -> ''

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

    # Listen for 'names' requests.
    @on 'names', async (channel, nicks) =>
      # Count the number of nicks in the nicks_in object
      users = (user for user of nicks).length
      # Update Channel.nicks with the nicks object sent from the network.
      Channels.update
        name: channel
      , {$set: {nicks, users}}

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

        # Add sender to user's PMs list unless it's already there.
        user = Meteor.users.findOne(@_id)
        unless to of user.profile.pms
          update Meteor.users, @_id
          , "profile.pms"
          , (pms) ->
            unless pms?
              pms = {}
            pms[from] = {unread: 0}
            return pms

    # Send a NAMES request when users joins, parts, or changes nick.
    for event in ['join', 'part', 'nick', 'kick', 'quit']
      @on event, async (channel) => @send 'NAMES', channel

    @on 'kick', async (channel, nick, kicker, reason, message) =>
      if nick is @username
        # Remove channel from user's channel list
        update Meteor.users, @_id, "profile.channels"
        , (channels) ->
          delete channels[channel]
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
