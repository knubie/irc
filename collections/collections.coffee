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

@Channels = new ChannelsCollection 'channels',
  transform: (doc) ->
    doc extends
      join: (nick) ->
        return if @nicks[nick]
        if _.isEmpty @nicks
          @nicks[nick] = '@'
        else
          @nicks[nick] = ''
      part: (nick) ->
        {nicks} = @
        delete nicks[nick]
        if _.isEmpty nicks
          Channels.remove @_id
        else
          Channels.update @_id, $set: {nicks}

Channels.allow
  insert: -> true
  update: (userId, channel) ->
    channel.nicks[Meteor.users.findOne(userId).username] is '@'
  remove: (userId, channel) ->
    _.isEmpty channel.nicks

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
      online: ->
        online = no
        if channel = Channels.findOne {name: @channel}
          for nick of channel.nicks
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
  #Accounts.onCreateUser (options, user) ->
    #user.join = (name) ->
      ## Get user's existing channel object
      #{channels} = user.profile
      ## Add the new channel if it's not there already.
      #unless name of channels
        #channels[name] =
          #ignore: []
          #verbose: false
          #unread: 0
          #mentions: 0
      ## Update the User with the new channels object.
      #Meteor.users.update user._id, $set: {'profile.channels': channels}

    #user.profile = options.profile if options.profile
    #return user

#if Meteor.isServer
  #@Channels._ensureIndex('name', {unique: 1, sparse: 1})
  #

if Meteor.isServer
  Accounts.validateNewUser (user) ->
    check user.username, String
    return true

  Accounts.validateNewUser (user) ->
    if /^[^\W]*$/.test user.username
      return true
    else
      throw new Meteor.Error 403, "Invalid characters in username."

  Accounts.validateNewUser (user) ->
    if user.username.length > 0
      return true
    else
      throw new Meteor.Error 403, "Username must have at least one character."

  Accounts.validateNewUser (user) ->
    if user.username.length < 10
      return true
    else
      throw new Meteor.Error 403, "Username must be less than 10 characters."
