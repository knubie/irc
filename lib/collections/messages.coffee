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
    @convos and user in @convos

@Messages = new Meteor.Collection 'messages',
  transform: (doc) -> new Message doc

if Meteor.isServer
  Messages.allow
    insert: (userId, message) ->
      check message.text, validMessageText
      user = Meteor.users.findOne(userId)
      if message.channel?
        channel = Channels.findOne({name: message.channel})
        channel.hasUser(user.username) \
        and not channel.isModerated() or (channel.isModerated() and channel.nicks[user.username] is '@')
      else
        true
    update: -> false
    remove: -> false

Messages.before.insert (userId, doc) ->
  if Meteor.isServer
    if doc.owner isnt 'server'
      user = Meteor.users.findOne(userId)

      # Set timestamp from the server.
      doc.createdAt = new Date()

      # Send action to the IRC server.
      if doc.type is 'action'
        client[user.username].action doc.channel or doc.to, doc.text
      else
        # Send message to the IRC server.
        client[user.username].say doc.channel or doc.to, doc.text

    if doc.to? and user = Meteor.users.findOne(username:doc.to)
      unless doc.from of user.profile.pms
        update Meteor.users, user._id
        , "profile.pms"
        , (pms) ->
          pms[doc.from] = {unread: []}
          return pms
      update Meteor.users, user._id
      , "profile.pms.#{doc.from}.unread"
      , (unread) ->
        unread.push doc._id unless doc._id in unread
        return unread

    # Manage mentions.
    if doc.channel? and doc.from isnt 'system' and doc.type isnt 'action'
      doc.convos = []
      for nick of Channels.findOne(name:doc.channel).nicks
        if regex.nick(nick).test(doc.text) \
        and user = Meteor.users.findOne(username:nick)
          if doc.from not in user.profile.channels[doc.channel].ignore \
          and doc.from isnt user.username
            # Push the nick to the Message's convo array.
            doc.convos.push nick

            # Update the mentioned user's profile with a new Message.
            #update Meteor.users, user._id
            #, "profile.channels.#{doc.channel}.mentions"
            #, (mentions) ->
              #mentions.push doc._id unless doc._id in mentions
              #return mentions
