Meteor.publish 'users', -> Meteor.users.find()
Meteor.publish 'channels', -> Channels.find()
Meteor.publish 'messages', (channel, limit) ->
  if channel is 'all'
    Messages.find
      owner: @userId or 'idletron'
    , {limit, sort:{createdAt: -1}}
  else
      Messages.find {owner: @userId or 'idletron', channel}
      , {limit, sort:{createdAt: -1}}

Meteor.publish 'mentions', (channel, limit) ->
  user = Meteor.users.findOne(@userId)
  if channel is 'all'
    Messages.find
      owner: @userId or 'idletron'
      convo: user.username
    , {limit, sort:{createdAt: -1}}
  else
    Messages.find {owner: @userId or 'idletron', channel}
    , {limit, sort:{createdAt: -1}}
