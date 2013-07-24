# Channels
#   name  : String
#   nicks : {name: status, ...}
#   topic : String
class ChannelsCollection extends Meteor.Collection
  find_or_create: (name, count, topic) ->
    count ?= 0
    topic ?= 'No topic set.'
    nicks = {}
    if name.isChannel and not @findOne({name})
      @findOne(@insert {name, count, topic, nicks})
    else
      @findOne({name})

@Channels = new ChannelsCollection 'channels',
  transform: (doc) ->
    doc extends
      messages: (opts) ->
        opts ?= {}
        if @name is 'all'
          selector = {@owner}
        else
          selector = {@owner, channel: @name}
        Messages.find selector, opts
      notifications: (opts) ->
        opts ?= {}
        @messages(opts).fetch().filter (msg) -> msg.type() is 'mention'
      join: (nick) ->
        return if @nicks[nick]
        if _.isEmpty @nicks
          @nicks[nick] = '@'
        else
          @nicks[nick] = ''
      part: (nick) ->
        delete nicks[nick]
        if _.isEmpty @nicks
          Channels.remove @_id



if Meteor.isServer
  Channels.allow
    insert: (userId, channel) ->
      duplicate = ->
        Channels.findOne
          owner: userId
          name: channel.name
      spaces = ->
        channel.name.indexOf(' ') >= 0
      channel.owner is userId and
      channel.name and
      not duplicate() and
      not spaces()
    remove: (userId, channel) ->
      channel.owner is userId
    update: (userId, channel) ->
      channel.owner is userId

# Messages
#   owner   : UserId
#   from    : String
#   channel : String
#   text    : String
#   type    : 'normal' / 'mention' / 'self'
#   time    : Date
@Messages = new Meteor.Collection 'messages',
  transform: (doc) ->
    doc extends
      type: ->
        {username} = Meteor.users.findOne(@owner)
        if @from is username
          return 'self'
        else if @from is 'system'
          return 'info'
        else
          if regex.nick(username).test @text then 'mention' else 'normal'
      convo: ->
        convo = ''
        for nick, status of Channels.findOne(name: @channel).nicks
          convo = nick if regex.nick(nick).test(@text)
        return convo
      online: ->
        online = no
        for nick, status of Channels.findOne(name: @channel).nicks
          if @from is nick then online = yes; break
        return online

# Users
# profile:
#   connecting: Boolean
#   channels: 
#     '#channelname':
#       ignore: [String, ...]
#       mode: String
