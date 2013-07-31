exec = Npm.require('child_process').exec

Meteor.users.update {}, $set: 'profile.connection': off
console.log 'turn everyone\'s connection off'

Meteor.startup ->
  # Make sure all users' connection status is 'off'

UserStatus.on "sessionLogin", (userId, sessionId, ipAddr) ->
  # Scenario 1:
  #   A user logs in and their profile.connection is off. This user is either
  #   1a) A free user who has logged out and is now logging back in.
  #     Action: reconnect.
  #   2a) A new user who has not yet connect to the irc server.
  #     Action: reconnect. If no client instance exists, log the user out
  #     so they can reauthenticate to create one.
  #   3a) Any user and the server has restart, all users' connection
  #   status has been set to off
  #     Action: log out all users so they can re-authenticate and connect to
  #     the irc server.
  #
  # Scenario 2:
  #   A user logs in and their profile.connection is on. This user is either
  #   1a)
  #     a paid user with persistent connection
  #     Action: none.
  user = Meteor.users.findOne userId
  if user.profile.connection is off
    if client[user.username]?
      client[user.username].connect()
    else
      # Log out all users.
      #Meteor.users.update userId, $set: 'services.resume.loginTokens' : []

UserStatus.on "sessionLogout", (userId, sessionId, ipAddr) ->
  user = Meteor.users.findOne userId
  if user.profile.connection is on and user.profile.account is 'free'
    client[user.username]?.disconnect()

#client['_bot'] = new IRC.Client 'localhost', "network_bot",
  #userName: "network_bot"
  #port: 6767
  #password: 'bot'
  #realName: 'N/A'
  #autoConnect: no
  #autoRejoin: no

#client['_bot'].on 'raw', async (msg) =>
  #if msg.command is 'rpl_list'
    #name = msg.args[1]
    #users = msg.args[2]
    #topic = msg.args[3]
    #ch = Channels.find_or_create name
    #Channels.update ch, $set: {users, topic}

#client['_bot'].on 'error', (msg) -> console.log msg

#client['_bot'].connect async ->
  #client['_bot'].join '#test'
  #Meteor.setInterval ->
    #client['_bot'].conn.write("LIST\r\n")
    ##client['_bot'].send 'LIST'
  #, 30000

########## Methods ##########
#
Meteor.methods
  remember: (username, password, _id) ->
    console.log 'remember..'
    console.log "username: #{username}"
    console.log "password: #{password}"
    console.log "_id: #{_id}"
    exec "cd ~/Development/hector/myserver.hect; hector identity remember #{username} #{password}", async ->
      console.log 'remember succeeded'
      client[username] ?= new Client {_id, username, password}
      client[username].connect()
    return null

  join: (username, channel) ->
    #check user, Match.ObjectIncluding(_id: String)
    console.log 'meteor.methods.join'
    client[username].join channel
    return null

  part: (user, channel) ->
    check user, Match.ObjectIncluding(_id: String)
    check channel, String
    client[user.username].part channel
    return null

  say: (user, channel, message) ->
    check user, Match.ObjectIncluding(_id: String)
    check channel, String
    check message, String
    client[user.username].say channel, message
    return null

  kick: (user, channel, username, reason) ->
    client[user.username].kick channel, username, reason
    return null

########## Publications ##########
#
Meteor.publish 'users', ->
  Meteor.users.find()

Meteor.publish 'channels', ->
  Channels.find()

#Meteor.publish 'messages', (channel, limit) ->
  #Messages.find()
Meteor.publish 'messages', (channel, limit) ->
  if channel is 'all'
    Messages.find {owner: @userId}, {limit, sort:{time: -1}}
  else
    Messages.find {owner: @userId, channel: channel}, {limit, sort:{time: -1}}
