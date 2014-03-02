Meteor.startup ->

  Meteor.users.find().forEach (user) ->
    # if lastLogin was less than 30 days ago.
    if (lastLogin = (new Date().getTime() - Meteor.users.findOne({username: user.username}).status.lastLogin)/1000/60/60/24) < 30
      # Connect to IRC
      Meteor.call 'connect', user.username, user._id
      #FIXME: why won't this work?
      #Meteor.setTimeout ->
        #Meteor.call 'disconnect', user.username
      #, 30*1000*60*60*24 - lastLogin

  # Create a new Idletron bot, which automatically gets added to all channels.
  # The purpose of this bot is to record messages, etc to the database.
  client.idletron = new Idletron 'Idletron'
  # Connect the bot to the server.
  client.idletron.connect async ->
    # For every channel.
    for channel in Channels.find().fetch()
      do (channel) ->
        # Bot joins the channel first.
        client.idletron.join channel.name, async ->
          for nick, mode of channel.nicks
            do (nick, mode) ->
              if client[nick]? and nick isnt client.idletron.nick
                # Then users join.
                client[nick].join channel.name, async ->
                  # bot ops user if he/she is an op
                  if mode is '@'
                    client.idletron.send 'MODE', channel.name, '+o', nick
          if channel.modes.length > 0
            client.idletron.send 'MODE', channel.name, "+#{channel.modes}"

  # Create a new Idletron bot, which automatically gets added to all channels.
  # The purpose of this bot is to record messages, etc to the database.
  #client.idletron = new Idletron
  ## Connect the bot to the server.
  #client.idletron.connect async ->
    ## Join all channels in the database.
    #for channel in Channels.find().fetch()
      #client.idletron.join channel.name

# When user renews session (reopens window, etc)
UserStatus.on "sessionLogin", (info) ->
  user = Meteor.users.findOne(info.userId)
  if user.profile.connection is off
    Meteor.call 'connect', user.username, user._id

# When user loses session (closes window, etc)
UserStatus.on "sessionLogout", (userId, sessionId, ipAddr) ->
  Meteor.users.update userId, $set: 'profile.awaySince': (new Date()).getTime()
