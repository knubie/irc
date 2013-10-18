# Messages
#   owner   : UserId
#   from    : String
#   channel : String
#   text    : String
#   type    : 'normal' / 'mention' / 'self'
#   time    : Date
#   read    : Boolean
#   mobile  : Boolean
@Messages = new Meteor.Collection 'messages',
  #TODO: replace (doc) -> with
  # extend
  #   type: ->
  #   ...
  # leave out destination for partial application
  transform: (doc) ->
    doc extends
      mentions: (user) ->
        regex.nick(user).test(@text)
      mentioned: ->
        mentions = []
        for nick of Channels.findOne(name:@channel).nicks
          if @mentions nick
            mentions.push nick
        return mentions

if Meteor.isServer
  Messages.allow
    insert: (userId, message) ->
      check message.text, validMessageText
      true
    update: -> false
    remove: -> false

Messages.before.insert (userId, doc) ->
  if Meteor.isServer and doc.owner isnt 'server'
    doc.createdAt = new Date()

Messages.after.insert (userId, doc) ->
  if Meteor.isServer and doc.owner isnt 'server'
    client[Meteor.users.findOne(userId).username].say doc.channel, doc.text
  if Meteor.isServer
    for nick of Channels.findOne(name:doc.channel).nicks
      if regex.nick(nick).test(doc.text) \
      and user = Meteor.users.findOne(username:nick)
        if doc.from not in user.profile.channels[doc.channel].ignore
          update Meteor.users, {username:nick}
          , "profile.channels.#{doc.channel}.mentions"
          , (mentions) ->
            unless Object::toString.call(mentions) is '[object Array]'
              mentions = []
            mentions.push doc._id unless doc._id in mentions
            return mentions

