Router.map ->
  @route 'home',
    path: '/'
    layoutTemplate: 'main_layout'
    action: ->
      if Meteor.user()
        @redirect('all channels')
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
      [ handlers.allMessages
        handlers.publicChannels ]
    action: ->
      if @ready()
        @render()
      else
        @render('loading')
        @render('channels', {to: 'channels'})

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
      if Meteor.isClient
        Session.set("##{@params.channel}.unread", 0)
    onStop: ->
      if Meteor.isClient
        Meteor.clearInterval @timeAgoInterval
        Session.set 'channel', null
    waitOn: ->
      messages = null
      joinedChannels = null
      if Meteor.isClient
        messages = handlers.messages["##{@params.channel}"]
        {joinedChannels} = handlers
      [ messages
        joinedChannels ?= Meteor.subscribe 'joinedChannels']
    data: ->
      {
        channel: Channels.findOne({name: "##{@params.channel}"}) or \
          {name: "##{@params.channel}", private: true}
        pm: null
      }
    action: ->
      channel = "##{@params.channel}"
      isKicked = false
      isPrivate = false
      if Meteor.isClient
        isKicked = Meteor.user()?.profile.channels[channel]?.kicked
        ifPrivate = Meteor.user() and not Channels.findOne({name: channel})
      if @ready()
        if Meteor.isClient
          if isKicked
            @render('kicked')
            @render('channels', {to: 'channels'})
            @render('channelHeader', {to: 'header'})
            @render('users', {to: 'users'})
          else if isPrivate
            @render('kicked')
            @render('channels', {to: 'channels'})
            @render('channelHeader', {to: 'header'})
          else
            @render()
      else
        @render('loading')
        @render('channels', {to: 'channels'})
        @render('channelHeader', {to: 'header'})
        @render('users', {to: 'users'})

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
    loadingTemplate: 'loading'
    fastRender: true
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
      joinedChannels = null
      if Meteor.isClient
        {joinedChannels} = handlers
      joinedChannels ?= Meteor.subscribe 'joinedChannels'
    data: ->
      {
        channel: Channels.findOne({name: "##{@params.channel}"})
        pm: null
        subpage: 'settings'
      }

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

