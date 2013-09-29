# Channels
#   name  : String
#   nicks : {name: status, ...}
#   topic : String
#   modes : Array
class ChannelsCollection extends Meteor.Collection
  find_or_create: (name, users, topic, modes) ->
    users ?= 0
    topic ?= 'No topic set.'
    modes ?= []
    nicks = {}
    if not @findOne {name}
      @findOne(@insert {name, users, topic, nicks, modes})
    else
      @findOne({name})

@Channels = new ChannelsCollection 'channels'

Channels.allow
  insert: (userId, channel) ->
    check doc.name, validChannelName
    check doc.nicks, Object
    check doc.topic, String
    check doc.modes, Array
  update: (userId, channel) ->
    channel.nicks[Meteor.users.findOne(userId).username] is '@'
    check doc.name, validChannelName
    check doc.nicks, Object
    check doc.topic, String
    check doc.modes, Array
  remove: (userId, channel) ->
    _.isEmpty channel.nicks
