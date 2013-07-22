# Channels
#   owner : UserId
#   name  : String
#   nicks : {name: status, ...}
#   topic : String
@Channels = new Meteor.Collection 'channels',
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
      status: ->
        {username} = Meteor.users.findOne(@owner)
        return @nicks[username]


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
