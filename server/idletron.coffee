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
    @on 'error', async (msg) =>
      console.log @nick
      Log.error msg

    # Log raw messages sent from the network.
    #@on 'raw', (msg) -> console.log msg

    #@on 'join', async (channel, nick, message) =>
      #unless Channels.findOne({name: channel}).nicks[nick]?
        #Messages.insert
          #owner: 'server'
          #channel: channel
          #text: "#{nick} has joined the channel."
          #createdAt: new Date()
          #from: 'system'

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

      if /^[?](.+)$/.test text # Listen for Wolfram queries.
        query = text.replace /^[?]\s*/g, '' # Extract query.
        wolfram.request query, async (answer) =>
          if answer
            @say to, answer
            Messages.insert
              channel: to
              text: answer
              mobile: false
              createdAt: new Date()
              from: 'Idletron'
              owner: 'server'
          else
            cleverbot.write query, async (response) =>
              @say to, response.message
              Messages.insert
                channel: to
                text: response.message
                mobile: false
                createdAt: new Date()
                from: 'Idletron'
                owner: 'server'

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
    @on 'names', async (channel, nicks) =>
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
        owner: 'server'
        channel: channel
        text: text
        createdAt: new Date()
        from: 'system'

      if user = Meteor.users.findOne({username: nick})
        update Meteor.users, user._id, "profile.channels"
        , (channels) ->
          channels[channel].kicked = true
          return channels

    # Send a NAMES request when users joins, parts, or changes nick.
    # TODO: re-write the node irc api to be more consistent
    @on 'join', async (channel, nick, message) => @send 'NAMES', channel
    @on 'part', async (channel, nick, reason, message) => @send 'NAMES', channel
    @on 'nick', async (oldnick, newnick, channels, message) =>
      for channel in channels
        @send 'NAMES', channels
    @on 'kick', async (channel, nick, kicker, reason, message) =>
      @send 'NAMES', channel
    @on 'quit', async (nick, reason, channels, message) =>
      for channel in channels
        @send 'NAMES', channel
    #for event in ['join', 'part', 'nick', 'kick', 'quit']
      #@on event, async (channel, nick, message) =>
        #console.log "#{event}: #{channel}"
        #@send 'NAMES', channel

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
