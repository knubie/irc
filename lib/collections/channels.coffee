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
    bans = []
    if not @findOne {name}
      @findOne(@insert {name, users, topic, nicks, modes, bans})
    else
      @findOne({name})

class Channel
  constructor: (doc) ->
    @[k] = doc[k] for k of doc
  hasUser: (user) ->
    user of @nicks
  isModerated: ->
    'm' in @modes
  isPrivate: ->
    's' in @modes or 'i' in @modes

@Channels = new ChannelsCollection 'channels',
  transform: (doc) -> new Channel doc

Channels.allow
  insert: (userId, channel) ->
    check channel.name, validChannelName
    check channel.nicks, Object
    check channel.topic, String
    check channel.modes, Array
  update: (userId, channel) ->
    channel.nicks[Meteor.users.findOne(userId).username] is '@'
    #check channel.name, validChannelName
    #check channel.nicks, Object
    #check channel.topic, String
    #check channel.modes, Array
  remove: (userId, channel) ->
    _.isEmpty channel.nicks
