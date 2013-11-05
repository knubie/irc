class Tron extends Client
  constructor: (listeners) ->
    @on 'message#', (from, to, text, message) =>
      if /^[>](.+)$/.test text # Listen for Wolfram queries.
        query = text.replace /^[>]\s*/g, '' # Extract query.
        wolfram.request query, (answer) =>
          if answer
            @say to, answer
          else
            @say to, "I don't know."

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
      Messages.insert
        owner: 'idletron'
        channel: channel
        text: "#{nick} was kicked by #{kicker}! \"#{reason}\""
        createdAt: new Date()
        from: 'system'
        convo: ''
        read: false

    # Send a NAMES request when users joins, parts, or changes nick.
    for event in ['join', 'part', 'nick', 'kick']
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
      text = "#{nick} was kicked by #{kicker}."
      text = text + " \"#{reason}\"" if reason
      Messages.insert
        owner: @_id
        channel: channel
        text: text
        createdAt: new Date()
        from: 'system'
        convo: ''
        read: false
      #if nick is @username
        #Channels.find({name}).part @username

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

    # Listen for incoming messages.
    #@on 'message#', async (from, to, text, message) =>

  connect: ->
    # Connect to the IRC network.
    super async =>
      console.log "connected #{@username}"
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

  say: (target, text) ->
    console.log "Target is: #{target}"
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
