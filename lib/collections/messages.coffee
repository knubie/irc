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
  transform: (doc) ->
    doc extends
      type: ->
        if @owner is 'idletron'
          return 'normal'
        else
          {username} = Meteor.users.findOne(@owner)
          if @from is username
            return 'self'
          else if @from is 'system'
            return 'info'
          else
            if @convo is username then 'mention' else 'normal'
      online: ->
        online = no
        if @channel?.isChannel()
          if channel = Channels.findOne {name: @channel}
            for nick of channel.nicks
              if @from is nick then online = yes; break
        else
          online = yes
        return online

if Meteor.isServer
  Messages.allow
    insert: (userId, message) ->
      check message.text, validMessageText
      true
    update: (userId, message) ->
      check message.text, validMessageText
      userId is message.owner
    remove: (userId, message) ->
      userId is message.owner

  Messages.before.insert (userId, doc) ->
    doc.createdAt = new Date()

  Messages.after.insert (userId, doc) ->
    client[Meteor.users.findOne(userId).username].say doc.channel, doc.text

