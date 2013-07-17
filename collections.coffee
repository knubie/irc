# Channels
#   owner : UserId
#   name  : String
#   nicks : {name: status, ...}
@Channels = new Meteor.Collection 'channels',
  transform: (doc) ->
    doc extends
      messages: (opts) ->
        opts ?= {}
        Messages.find
          owner: @owner
          channel: if @name is 'all' then '' else @name
        , opts
      notifications: (opts) ->
        opts ?= {}
        @messages().fetch().filter (msg) -> msg.type() is 'mention'
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
      channel.owner is userId and channel.name and not duplicate()

    remove: (userId, channel) ->
      channel.owner == userId

    update: (userId, channel) ->
      channel.owner == userId

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
        else
          nickExp = new RegExp "(^|[^\\S])(#{username})($|([:,.!]|[^\\S]))"
          if nickExp.test @text
            return 'mention'
          else
            return 'normal'
      convo: ->
        ch = Channels.findOne {name: @channel}
        convo = ''
        for nick, status of Channels.findOne(name: @channel).nicks
          nickExp = new RegExp "(^|[^\\S])(#{nick})($|([:,]|[^\\S]))"
          convo = nick if nickExp.test(@text)
        return convo
      online: ->
        online = no
        for nick, status of Channels.findOne(name: @channel).nicks
          online = yes if @from is nick; break
        return online
