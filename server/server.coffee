Meteor.startup ->

  # first, remove configuration entry in case service is already configured
  Accounts.loginServiceConfiguration.remove
    service: "github"

  Accounts.loginServiceConfiguration.insert
    service: "weibo"
    clientId: "20da6e29dafcf36ad05a"
    secret: "d11c42acaba2bc3a9f847c1aa46657b193ab5f6c"

  Meteor.users.find().forEach (user) ->
    # Connect to IRC
    client[user.username] ?= new Bot user
    client[user.username].connect()

    # Observe messages to create unread count
    Messages.find({owner: user._id}).observeChanges
      added: (id, doc) ->
        unless doc.read
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

      changed: (id, fields) ->
        if fields.read
          doc = Messages.findOne(id)
          user = Meteor.users.findOne(user._id)
          {channels} = user.profile
          unless typeof channels[doc.channel].unread is 'object'
            channels[doc.channel].unread = []
          if (i = channels[doc.channel].unread.indexOf(id)) > -1
            channels[doc.channel].unread.splice i, 1
          #channels[doc.channel].unread = _.uniq channels[doc.channel].unread
          if doc.convo is user.username and \
          doc.from not in user.profile.channels[doc.channel].ignore
            unless typeof channels[doc.channel].mentions is 'object'
              channels[doc.channel].mentions = []
            if (i = channels[doc.channel].mentions.indexOf(id)) > -1
              channels[doc.channel].mentions.splice i, 1
            #channels[doc.channel].mentions = _.uniq channels[doc.channel].mentions
          Meteor.users.update(doc.owner, {$set: {'profile.channels': channels}})

          #unless doc.channel.isChannel() #PM
            #if Meteor.user().profile.notifications
              #notifications[id] ?= new Notification "#{doc.from}", doc.text
              #notifications[id].showOnce()

  # Create a new Idletron bot, which automatically gets added to all channels.
  # The purpose of this bot is to record messages, etc to the database.
  client.idletron = new Idletron
  # Connect the bot to the server.
  client.idletron.connect async ->
    # Join all channels in the database.
    for channel in Channels.find().fetch()
      client.idletron.join channel.name

# When user loses session (closes window, etc)
UserStatus.on "sessionLogin", (userId, sessionId, ipAddr) ->
  # Do anything here?

# When user renews session (reopens window, etc)
UserStatus.on "sessionLogout", (userId, sessionId, ipAddr) ->
  Meteor.users.update userId, $set: 'profile.awaySince': (new Date()).getTime()
