# Messages
#   owner   : UserId
#   from    : String
#   channel : String
#   text    : String
#   type    : 'normal' / 'mention' / 'self'
#   time    : Date
#   read    : Boolean
#   mobile  : Boolean
class @Message
  constructor: (doc) ->
    @[k] = doc[k] for k of doc
  mentions: (user) ->
    regex.nick(user).test(@text)
  mentioned: ->
    mentions = []
    for nick of Channels.findOne(name:@channel).nicks
      if @mentions nick
        mentions.push nick
    return mentions

@Messages = new Meteor.Collection 'messages',
  transform: (doc) -> new Message doc

if Meteor.isServer
  Messages.allow
    insert: (userId, message) ->
      check message.text, validMessageText
      true
    update: -> false
    remove: -> false

Messages.after.insert (userId, doc) ->
  if Meteor.isServer
    if doc.owner isnt 'server'
      # Set timestamp from the server.
      doc.createdAt = new Date()
      # Send message to the IRC server.
      client[Meteor.users.findOne(userId).username].say doc.channel or doc.to, doc.text

    # Manage mentions.
    if doc.channel?
      doc.convos = []
      for nick of Channels.findOne(name:doc.channel).nicks
        if regex.nick(nick).test(doc.text) \
        and user = Meteor.users.findOne(username:nick)
          if doc.from not in user.profile.channels[doc.channel].ignore
            # Push the nick to the Message's convo array.
            doc.convos.push nick

            # Update the mentioned user's profile with a new Message.
            update Meteor.users, user._id
            , "profile.channels.#{doc.channel}.mentions"
            , (mentions) ->
              unless Object::toString.call(mentions) is '[object Array]'
                mentions = []
              mentions.push doc._id unless doc._id in mentions
              return mentions

