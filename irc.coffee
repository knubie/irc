#TODO: Add ignore option.
#TODO: Differentiate your own messages.
#TODO: Add search.
#TODO: Add PM support.
#TODO: Add autocomplete.
@Channels = new Meteor.Collection 'channels'
Channels.allow
  insert: (userId, channel) ->
    duplicate = ->
      Channels.findOne
        owner: userId
        name: channel.name
    channel.owner == userId and channel.name and not duplicate()

  remove: (userId, channel) ->
    channel.owner == userId

@Messages = new Meteor.Collection 'messages'

if Meteor.isClient

  Template.home.events
    'submit #auth-form': (e,t) ->
      e.preventDefault()
      username = t.find('#auth-nick').value
      password = t.find('#auth-pw').value

      if Meteor.users.findOne {username}
        Meteor.loginWithPassword username, password
      else
        Accounts.createUser
          username: username
          password: password
          profile:
            connecting: true
        , (err) ->
          Channels.insert
            owner: Meteor.userId()
            name: 'all'
          Meteor.apply 'newClient', [Meteor.user()]

  Template.dashboard.connecting = ->
    return Meteor.user().profile.connecting

  Template.channels.events
    'submit #new-channel': (e, t) ->
      e.preventDefault()
      name = t.find('#new-channel-name').value
      t.find('#new-channel-name').value = ''
      newChannel = Channels.insert
        owner: Meteor.userId()
        name: name
        nicks: []
      Meteor.apply 'join', [Meteor.user(), Channels.findOne newChannel]

  Template.channels.channels = ->
    Channels.find
      owner: Meteor.userId()

  Template.channels.channel_selected = ->
    Session.get 'channel'

  Template.channel.events
    'click li': (e,t) ->
      #FIXME: make this work for touch.
      Session.set 'channel', @name
      $('.nav > li > a > i').removeClass 'icon-white'
      $(e.currentTarget).find('i').addClass 'icon-white'

    'click .close': ->
      Channels.remove @_id
      Meteor.apply 'part', [Meteor.user(), @name]
      Session.set 'channel', 'all'

  Template.channel.active = ->
    if Session.get('channel') is @name then 'active' else 'inactive'

  Template.channel.alert_count = ->
    if @name is 'all'
      messages = Messages.find
        owner: Meteor.userId()
        alert: true
    else
      messages = Messages.find
        owner: Meteor.userId()
        to: @name
        alert: true
    count = messages.map((msg) -> msg).length
    if count > 0 then count else ''

  Template.messages.rendered = ->
    $(window).scrollTop(99999)
    #FIXME: why aint this workin'

  Template.messages.events
    'submit #say': (e, t) ->
      e.preventDefault()
      message = t.find('#say-input').value
      $('#say-input').val('')
      Meteor.apply 'say', [Meteor.user(), Session.get('channel'), message]
      Messages.insert
        from: Meteor.user().username
        to: Session.get('channel')
        text: message
        time: moment()
        owner: Meteor.userId()
        type: 'self'

  Template.messages.channel = ->
    Session.get('channel')

  Template.messages.messages = ->
    if Session.get('channel') is 'all'
      messages = Messages.find
        owner: Meteor.userId()
    else
      messages = Messages.find
        owner: Meteor.userId()
        to: Session.get('channel')
    prev = null
    messages.map (msg) ->
      msg.prev = prev
      prev = msg

  Template.messages.notifications = ->
    messages = Messages.find
      owner: Meteor.userId()
      to: Session.get('channel')
      type: 'mention'
    messages.map((msg) -> msg).reverse()

  Template.message.rendered = ->
    #FIXME: this causes html to go unescaped.
    urlExp = /(\b(https?|ftp|file):\/\/[-A-Z0-9+&@#\/%?=~_|!:,.;]*[-A-Z0-9+&@#\/%=~_|])/ig
    #$(@find('p')).html(@data.text.replace(urlExp,"<a href='$1' target='_blank'>$1</a>"))

  Template.message.events
    'click .reply': ->
      console.log 'clicked reply'
      $('#say-input').val("#{@from} ")
      $('#say-input').focus()

  Template.message.joinToPrev = ->
    unless @prev is null
      @prev.from is @from

  Template.message.all = ->
    Session.get('channel') is 'all'

  Template.message.timeAgo = ->
    #FIXME: doesn't work for message sent by user.
    moment(@time._d).fromNow()

  Template.message.message_class = ->
    ch = Channels.findOne {name: @to, owner: Meteor.userId()}
    console.log @to
    console.log ch
    status = 'offline'
    for nick in ch.nicks
      status = 'online' if @from is nick
    return status + ' ' + @type
    @type

  Template.notifications.relativeTime = ->
    moment(@time).fromNow()

  Template.notifications.events
    'click li': ->
      $(window).scrollTop $("##{@_id}").offset().top

    'click .close': ->
      Messages.update
        _id: @_id
      , {$set: {'type': 'normal'}}

if Meteor.isServer

  Fiber = Npm.require("fibers")

  Meteor.startup ->

    clients = {}
    join = (user, channel) ->
      if /^[#](.*)$/.test channel.name
        clients[user._id].join channel.name

    connect = (user) ->
      # Set user status to connecting.
      Meteor.users.update user._id, $set: {'profile.connecting': true}

      # Create new IRC instance.
      clients[user._id] = new IRC.Client 'irc.freenode.net', user.username,
        autoConnect: false
      clients[user._id].on 'error', (msg) -> console.log msg

      clients[user._id].connect Meteor.bindEnvironment ->
        console.log 'connected.'
        # Set user status to connected.
        Meteor.users.update user._id, $set: {'profile.connecting': false}
        # Listen for messages and create new Messages doc for each one.
        clients[user._id].on 'message', Meteor.bindEnvironment (from, to, text, message) ->
          if text.match ".*#{user.username}.*"
            type = 'mention'
          else
            type = 'normal'
          Messages.insert
            from: from
            to: to
            text: text
            time: new Date
            owner: user._id
            type: type
        , (err) -> console.log err
        # Listen for when the client requests names from a channel
        # and log them to corresponding the channel document.
        clients[user._id].on 'names', Meteor.bindEnvironment (channel,nicks) ->
          nicksArray = for nick, status of nicks
            nick
          console.log nicksArray
          Channels.update
            name: channel
            owner: user._id
          , {$set: {'nicks': nicksArray}}
        , (err) -> console.log err
        # Listen for when users join or part a channel.
        # Request names for that channel from the server.
        # When names are request the names listener will be called
        # which sets the name to the corresponding channel doc.
        clients[user._id].on "join", Meteor.bindEnvironment (chan) ->
          clients[user._id].send 'NAMES', chan
        , (err) -> console.log err
        clients[user._id].on "part", Meteor.bindEnvironment (chan) ->
          clients[user._id].send 'NAMES', chan
        , (err) -> console.log err
        # Join all channels subscribed to by user.
        channels = Channels.find owner: user._id
        channels.forEach (channel) -> join user, channel
      , (err) -> console.log err

    #FIXME: Sometimes this connects multiple times.
    #users = Meteor.users.find {}
    #users.forEach (user) -> connect user

    Meteor.methods
      newClient: (user) ->
        connect user
      join: (user, channel) ->
        join user, channel
      part: (user, channel) ->
        clients[user._id].part channel
      say: (user, channel, message) ->
        clients[user._id].say channel, message
