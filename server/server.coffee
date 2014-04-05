Meteor.startup ->

  # Initialize mail
  process.env.MAIL_URL = 'smtp://postmaster%40jupe.io:0a-z-0l5nxq8@smtp.mailgun.org:587'

  Accounts.urls.resetPassword = (token) ->
    Meteor.absoluteUrl "reset-password/#{token}"
  
  Accounts.emailTemplates.from = 'accounts@jupe.io'
  #Accounts.emailTemplates =
    #from: 'accounts@jupe.io'
    #siteName: 'jupe.io'
    #resetPassword:
      #subject: (user) ->
        #"Reset your jupe.io password"

  Meteor.users.find().forEach (user) ->
    # if lastLogin was less than 30 days ago.
    if (new Date().getTime() - user.status.lastLogin)/1000/60/60/24 < 30
      # Connect to IRC
      Meteor.call 'connect', user.username, user._id
      #FIXME: why won't this work?
      #Meteor.setTimeout ->
        #Meteor.call 'disconnect', user.username
      #, 30*1000*60*60*24 - lastLogin
    else
      if user.profile.connection is on
        Meteor.users.update user._id, $set: {'profile.connection': off}

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

# When user renews session (reopens window, etc)
UserStatus.events.on "connectionLogin", (info) ->
  user = Meteor.users.findOne(info.userId)
  if user.profile.connection is off
    Meteor.call 'connect', user.username, user._id

# When user loses session (closes window, etc)
UserStatus.events.on "connectionLogout", (info) ->
  Meteor.users.update info.userId, $set: 'status.awaySince': new Date().getTime()
