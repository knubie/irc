Meteor.startup ->
  # Log out all users when server starts.
  # This is necessary so that users can reauthenticate with the irc daemon
  Meteor.users.update {}
  , {$set: {'services.resume.loginTokens' : []}}
  , {multi: true}
  console.log 'remove login tokens'

  # Create a new Idletron bot, which automatically gets added to all channels.
  # The purpose of this bot is to record messages, etc to the database.
  client.idletron = new Idletron
  # Connect the bot to the server.
  client.idletron.connect async ->
    # Join all channels in the database.
    for channel in Channels.find().fetch()
      client.idletron.join channel.name

UserStatus.on "sessionLogin", (userId, sessionId, ipAddr) ->
  # Do anything here?

UserStatus.on "sessionLogout", (userId, sessionId, ipAddr) ->
  # Do anything here?
  # Perhaps set away flag..
