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
  Template.dashboard.connecting = ->
    return Meteor.user().profile.connecting

  Template.auth.events
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
          Meteor.apply 'newBot', [Meteor.user()]

  Template.channels.events
    'submit #new-channel': (e, t) ->
      e.preventDefault()
      name = t.find('#new-channel-name').value
      t.find('#new-channel-name').value = ''
      # Add channel to Collection.
      Channels.insert
        owner: Meteor.userId()
        name: name
      # Join channel.
      Meteor.apply 'join', [Meteor.user(), name]

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

  Template.messages.messages_alerts = ->
    messages = Messages.find
      owner: Meteor.userId()
      to: Session.get('channel')
      alert: true
    messages.map((msg) -> msg).reverse()

  Template.message.rendered = ->
    urlExp = /(\b(https?|ftp|file):\/\/[-A-Z0-9+&@#\/%?=~_|!:,.;]*[-A-Z0-9+&@#\/%=~_|])/ig
    $(@find('p')).html(@data.text.replace(urlExp,"<a href='$1' target='_blank'>$1</a>"))

  Template.message.events
    'click .reply': ->
      console.log 'clicked reply'
      $('#say-input').val("#{@from} ")
      $('#say-input').focus()

  Template.message.relativeTime = ->
    #FIXME: doesn't work for message sent by user.
    moment(@time._d).fromNow()

  Template.message.alert_class = ->
    'alert-info' if @alert

  Template.message_alert.relativeTime = ->
    moment(@time._d).fromNow()

  Template.message_alert.events
    'click li': ->
      $(window).scrollTop $("##{@_id}").offset().top

    'click .close': ->
      Messages.update
        _id: @_id
      , {$set: {'alert': false}}

if Meteor.isServer
  Meteor.startup ->
    Fiber = Npm.require("fibers")
    clients = {}
    users = Meteor.users.find {}
    connect = (user) ->
      console.log "Connecting #{user.username}"
      Meteor.users.update
        _id: user._id
      , {$set: {'profile.connecting': true}}

      clients[user.username] = new IRC.Client 'irc.choopa.net', user.username,
        autoConnect: false

      clients[user.username].on 'error', (msg) ->
        console.log msg

      clients[user.username].connect ->
        console.log "#{user.username} connected to irc."
        Fiber(->
          Meteor.users.update
            _id: user._id
          , {$set: {'profile.connecting': false}}

          channels = Channels.find {owner: user._id}
          channels.forEach (channel) ->
            console.log "Joining channel #{channel.name}"
            if /^[#](.*)$/.test channel.name
              clients[user.username].join channel.name

          clients[user.username].on 'message', (from, to, text, message) ->
            Fiber(->
              Messages.insert
                from: from
                to: to
                text: text
                time: moment()
                owner: user._id
                alert: if text.match ".*#{user.username}.*" then true else false
            ).run()
        ).run()

    #FIXME: Sometimes this connects multiple times.
    #users.forEach (user) -> connect user

    Meteor.methods
      newBot: (user) ->
        connect user

      join: (user, channel) ->
        clients[user.username].join channel

      part: (user, channel) ->
        clients[user.username].part channel

      say: (user, channel, message) ->
        clients[user.username].say channel, message
