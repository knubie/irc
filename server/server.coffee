Meteor.startup ->

  # first, remove configuration entry in case service is already configured
  Accounts.loginServiceConfiguration.remove
    service: "github"

  Accounts.loginServiceConfiguration.insert
    service: "weibo"
    clientId: "20da6e29dafcf36ad05a"
    secret: "d11c42acaba2bc3a9f847c1aa46657b193ab5f6c"

  Meteor.users.find().forEach (user) ->
    # Connect to IRC
    client[user.username] ?= new Bot user
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
