Router.configure
  loadingTemplate: 'loading'

Router.map ->
  @route 'home',
    path: '/'
    layoutTemplate: 'main_layout'
    action: ->
      if Meteor.user()
        @redirect 'all channels'
      else
        @render 'home'

  @route 'login',
    layoutTemplate: 'account_layout'

  @route 'signup',
    layoutTemplate: 'account_layout'

  @route 'account',
    layoutTemplate: 'main_layout'
    data: -> Meteor.user()

  @route 'explore',
    layoutTemplate: 'main_layout'
    loadingTemplate: 'loading'
    waitOn: ->
      handlers.publicChannels ?= Meteor.subscribe 'publicChannels'

  @route 'user',
    path: 'users/:user'
    layoutTemplate: 'main_layout'
    template: 'user_profile'
    loadingTemplate: 'loading'
    data: ->
      Meteor.users.findOne(username: @params.user)

  @route 'all channels',
    path: '/'
    layoutTemplate: 'channel_layout'
    template: 'messages'
    #fastRender: true
    yieldTemplates:
      'channels': {to: 'channels'}
    waitOn: ->
      [ handlers.allMessages()
        handlers.joinedChannels() ]
    action: ->
      if @ready()
        @render()
        query = Messages.find(channel: "##{@params.channel}")
        init = true
        query.observeChanges
          added: (id, message) =>
            unless init
              beepAndNotify(id, message)
              unless document.hasFocus()
                unread += 1
                window.document.title = "(#{unread}) Jupe"
              unless Session.equals 'channel', message.channel
                channelUnread = Session.get("#{message.channel}.unread") or 0
                Session.set("#{message.channel}.unread", channelUnread + 1)
        init = false
      else
        @render('loading')

  @route 'channel',
    path: '/channels/:channel'
    layoutTemplate: 'channel_layout'
    template: 'messages'
    #fastRender: true
    yieldTemplates:
      'channels': {to: 'channels'}
      'channelHeader': {to: 'header'}
      'say': {to: 'say'}
      'users': {to: 'users'}
    onBeforeAction: ->
      channel = "##{@params.channel}"
      if Meteor.isClient
        Session.set 'channel', channel
        Meteor.call 'join', Meteor.user().username, channel if Meteor.user()
        @timeAgoInterval = Meteor.setInterval ->
          timeAgoDep.changed()
        , 60000
    onAfterAction: ->
    onStop: ->
      if Meteor.isClient
        Meteor.clearInterval @timeAgoInterval
        Session.set 'channel', null
    waitOn: ->
      [ handlers._messages["##{@params.channel}"]
        handlers.joinedChannels ]
    data: ->
      {
        channel: => Channels.findOne name: "##{@params.channel}"
        #channel: Channels.findOne({name: "##{@params.channel}"}) or \
          #{name: "##{@params.channel}", private: true}
        pm: null
      }
    action: ->
      channel = "##{@params.channel}"
      if @ready()
        isKicked = Meteor.user()?.profile.channels[channel]?.kicked
        isPrivate = Meteor.user() and not Channels.findOne({name: channel})
        if isKicked
          @render('kicked')
        else if isPrivate
          @render('kicked')
        else
          @render()
          Session.set("##{@params.channel}.unread", 0)

          update Meteor.users, Meteor.userId()
          , "profile.channels.##{@params.channel}.mentions"
          , (mentions) ->
            return []
      else
        @render 'loading'

  @route 'mentions',
    path: '/channels/:channel/mentions'
    template: 'mentions'
    layoutTemplate: 'channel_layout'
    yieldTemplates:
      'channels': {to: 'channels'}
      'channelHeader': {to: 'header'}
    onBeforeAction: ->
      channel = "##{@params.channel}"
      Session.set 'subPage', 'mentions'
      Session.set 'channel', channel
    onStop: ->
      channel = "##{@params.channel}"
      Session.set 'subPage', null
      update Meteor.users, Meteor.userId()
      , "profile.channels.#{channel}.mentions"
      , (mentions) -> return []
    waitOn: ->
      handlers.messages = \
      Meteor.subscribe 'mentions', "##{@params.channel}", PERPAGE
    data: ->
      {
        channel: Channels.findOne({name: "##{@params.channel}"})
        pm: null
      }

  @route 'settings',
    path: '/channels/:channel/settings'
    layoutTemplate: 'channel_layout'
    template: 'settings'
    #fastRender: true
    yieldTemplates:
      'channels': {to: 'channels'}
      'channelHeader': {to: 'header'}
    onBeforeAction: ->
      channel = "##{@params.channel}"
      Session.set 'subPage', 'settings'
      Session.set 'channel', channel
    onStop: ->
      Session.set 'subPage', null
    waitOn: ->
      handlers.joinedChannels()
    data: ->
      {
        channel: => Channels.findOne name: "##{@params.channel}"
        pm: null
        subpage: 'settings'
      }
    action: ->
      if @ready()
        @render()
      else
        @render 'loading'

  @route 'messages',
    path: '/messages/:user'
    template: 'messages'
    layoutTemplate: 'channel_layout'
    loadingTemplate: 'loading'
    yieldTemplates:
      'channels': {to: 'channels'}
      'say': {to: 'say'}
    onAfterAction: ->
      Session.set 'subPage', 'messages'
      if Meteor.user()
        unless @params.user of Meteor.user().profile.pms
          update Meteor.users, Meteor.userId()
          , "profile.pms"
          , (pms) =>
            pms[@params.user] = {unread: []}
            return pms
    waitOn: ->
      handlers.messages = \
      Meteor.subscribe 'privateMessages', @params.user, PERPAGE * (Session.get('messages.page') + 1)
    data: ->
      {
        channel: null
        pm: @params.user
        subpage: 'messages'
      }

  @route 'tos',
    path: '/tos'
    layoutTemplate: 'tos'

  @route 'forgotPassword',
    path: '/forgot-password'
    layoutTemplate: 'account_layout'

  @route 'resetPassword',
    path: '/reset-password/:token'
    layoutTemplate: 'account_layout'
    onBeforeAction: ->
      Session.set 'token', @params.token

