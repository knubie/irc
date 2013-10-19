Meteor.publish 'users', -> Meteor.users.find()
Meteor.publish 'publicChannels', ->
  #Channels.find {private: {$ne: true}}
  Channels.find modes: $nin: ['s', 'i']
Meteor.publish 'joinedChannels', ->
  query = {}
  username = Meteor.users.findOne(@userId).username
  query["nicks.#{username}"] = {$exists: true}
  Channels.find query
Meteor.publish 'messages', (channel, limit) ->
  if channel is 'all'
    Messages.find {}, {limit, sort:{createdAt: -1}}
  else
    Messages.find {channel}, {limit, sort:{createdAt: -1}}

Meteor.publish 'mentions', (channel, limit) ->
  user = Meteor.users.findOne(@userId)
  Messages.find
    convos: $in: [user.username]
  , {limit, sort:{createdAt: -1}}
