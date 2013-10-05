# Messages
#   owner   : UserId
#   from    : String
#   channel : String
#   text    : String
#   type    : 'normal' / 'mention' / 'self'
#   time    : Date
#   read    : Boolean
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
      userId is message.owner
    update: (userId, message) ->
      check message.text, validMessageText
      userId is message.owner
    remove: (userId, message) ->
      userId is message.owner

  Messages.after.insert (userId, doc) ->
    unless doc.read
      id = doc._id
      user = Meteor.users.findOne(doc.owner)
      {unread} = user.profile.channels[doc.channel]
      {mentions} = user.profile.channels[doc.channel]

      # Update unread count
      unread = [] unless typeof unread is 'object' #TODO: remove this
      unread.push id if unread.indexOf(id) is -1

      # Update mentions count
      if doc.convo is user.username \
      and doc.from not in user.profile.channels[doc.channel].ignore
        mentions = [] unless typeof mentions is 'object' #TODO: remove this
        mentions.push id if mentions.indexOf(id) is -1

      # Update user doc
      $set = {}
      $set["profile.channels.#{doc.channel}.unread"] = unread
      $set["profile.channels.#{doc.channel}.mentions"] = mentions
      Meteor.users.update(doc.owner, {$set})

  Messages.before.update (userId, doc, fieldNames, modifier, options) ->

    console.log doc._id
    console.log modifier['$set'].read
    if modifier['$set'].read
    #if fields.read
      #doc = Messages.findOne(id)
      id = doc._id
      user = Meteor.users.findOne(doc.owner)
      {channels} = user.profile
      unless typeof channels[doc.channel].unread is 'object'
        channels[doc.channel].unread = []
      if (i = channels[doc.channel].unread.indexOf(id)) > -1
        console.log 'doc in unread array'
        channels[doc.channel].unread.splice i, 1
      ##channels[doc.channel].unread = _.uniq channels[doc.channel].unread
      if doc.convo is user.username and \
      doc.from not in user.profile.channels[doc.channel].ignore
        unless typeof channels[doc.channel].mentions is 'object'
          channels[doc.channel].mentions = []
        if (i = channels[doc.channel].mentions.indexOf(id)) > -1
          console.log 'doc in mentions array'
          channels[doc.channel].mentions.splice i, 1
        ##channels[doc.channel].mentions = _.uniq channels[doc.channel].mentions
      Meteor.users.update(doc.owner, {$set: {'profile.channels': channels}})
