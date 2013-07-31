# Channels
#   name  : String
#   nicks : {name: status, ...}
#   topic : String
class ChannelsCollection extends Meteor.Collection
  find_or_create: (name, users, topic) ->
    console.log 'find or create'
    users ?= 0
    topic ?= 'No topic set.'
    nicks = {}
    if name.isChannel and not @findOne({name})
      @findOne(@insert {name, users, topic, nicks})
    else
      @findOne({name})

@Channels = new ChannelsCollection 'channels',
  transform: (doc) ->
    doc extends
      join: (nick) ->
        console.log 'channels.join'
        return if @nicks[nick]
        console.log 'nick is not in channel\'s nick list'
        if _.isEmpty @nicks
          @nicks[nick] = '@'
        else
          @nicks[nick] = ''
      part: (nick) ->
        nicks = _.clone @nicks
        delete nicks[nick]
        if _.isEmpty @nicks
          Channels.remove @_id
        else
          Channels.update @_id, $set: {nicks}

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
#   connection: Boolean
#   account: free/personal/business
#   channels: 
#     '#channelname':
#       ignore: [String, ...]
#       mode: String

#if Meteor.isServer
  #@Channels._ensureIndex('name', {unique: 1, sparse: 1})
