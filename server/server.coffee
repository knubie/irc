Meteor.startup ->
  Meteor.users.find().forEach (user) ->
    client[user.username] ?= new Bot
      _id: user._id
      username: user.username
    #if user.services.resume.loginTokens.length > 0
    client[user.username].connect()

  # Create a new Idletron bot, which automatically gets added to all channels.
  # The purpose of this bot is to record messages, etc to the database.
  client.idletron = new Idletron
  # Connect the bot to the server.
  client.idletron.connect async ->
    # Join all channels in the database.
    for channel in Channels.find().fetch()
      client.idletron.join channel.name

# When user loses session (closes window, etc)
UserStatus.on "sessionLogin", (userId, sessionId, ipAddr) ->
  # Do anything here?

# When user renews session (reopens window, etc)
UserStatus.on "sessionLogout", (userId, sessionId, ipAddr) ->
  Meteor.users.update userId, $set: 'profile.awaySince': (new Date()).getTime()
