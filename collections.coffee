@Channels = new Meteor.Collection 'channels'
Channels.allow
  insert: (userId, channel) ->
    duplicate = ->
      Channels.findOne
        owner: userId
        name: channel.name
    channel.owner == userId and channel.name and not duplicate()

  remove: (userId, channel) ->
    channel.owner == userId

@Messages = new Meteor.Collection 'messages'
