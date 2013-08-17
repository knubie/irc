#Meteor.users.update {}, $set: 'profile.connection': off
Meteor.users.update {}, $set: 'services.resume.loginTokens' : []

Meteor.startup ->
  client.idletron = new Idletron
  client.idletron.connect async ->
    for channel in Channels.find().fetch()
      console.log channel.name
      client.idletron.join channel.name
  # Make sure all users' connection status is 'off'

UserStatus.on "sessionLogin", (userId, sessionId, ipAddr) ->
  # Do anything here?

UserStatus.on "sessionLogout", (userId, sessionId, ipAddr) ->
  # Do anything here?

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

########## Publications ##########

Meteor.publish 'users', ->
  Meteor.users.find()

Meteor.publish 'channels', ->
  Channels.find()

#Meteor.publish 'messages', (channel, limit) ->
  #Messages.find()
Meteor.publish 'messages', (channel, limit) ->
  if channel is 'all'
    if @userId
      Messages.find {owner: @userId}, {limit, sort:{time: -1}}
    else
      Messages.find {owner: 'idletron'}, {limit, sort:{time: -1}}
  else
    if @userId
      Messages.find {owner: @userId, channel: channel}, {limit, sort:{time: -1}}
    else
      Messages.find {owner: 'idletron', channel: channel}, {limit, sort:{time: -1}}
