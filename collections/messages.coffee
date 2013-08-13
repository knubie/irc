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
          if @convo is username then 'mention' else 'normal'
      online: ->
        online = no
        if @channel.isChannel()
          if channel = Channels.findOne {name: @channel}
            for nick of channel.nicks
              if @from is nick then online = yes; break
        else
          online = yes
        return online

Messages.allow
  insert: (userId, message) ->
    check message.text, validMessageText
    userId is message.owner
  update: (userId, message) ->
    check message.text, validMessageText
    userId is message.owner
  remove: (userId, message) ->
    userId is message.owner

