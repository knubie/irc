# Channels
#   owner : UserId
#   name  : String
#   nicks : [String, ...]
@Channels = new Meteor.Collection 'channels',
  transform: (doc) ->
    doc extends
      messages: ->
        Messages.find
          owner: @owner
          to: @name
      notifications: ->
        if @name is 'all'
          nots = Messages.find
            owner: @owner
            type: 'mention'
        else
          nots = Messages.find
            owner: @owner
            to: @name
            type: 'mention'
        return nots.count()

Channels.allow
  insert: (userId, channel) ->
    duplicate = ->
      Channels.findOne
        owner: userId
        name: channel.name
    channel.owner == userId and channel.name and not duplicate()

  remove: (userId, channel) ->
    channel.owner == userId

  update: (userId, channel) ->
    channel.owner == userId

# Messages
#   owner : UserId
#   from  : String
#   to    : String
#   text  : String
#   type  : 'normal' / 'mention' / 'self'
#   time  : Date
@Messages = new Meteor.Collection 'messages'
