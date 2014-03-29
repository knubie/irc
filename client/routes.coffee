Router.map ->
  @route 'home',
    path: '/'
    layoutTemplate: 'main_layout'
    loadingTemplate: 'loading'
    onBeforeAction: ->
      if Meteor.user()
        @redirect 'loggedInHome'

  @route 'loggedInHome',
    path: '/'
    layoutTemplate: 'channel_layout'
    loadingTemplate: 'loading'
    onBeforeAction: ->
      unless Meteor.user()
        @redirect 'home'
      Session.set 'subPage', 'messages'
    waitOn: ->
      channels = (channel for channel of Meteor.user().profile.channels)
      Meteor.subscribe 'messages', channels, PERPAGE
    data: ->
      {
        channel: null
        pm: null
        subpage: 'messages'
      }
    action: ->
      if @ready()
        @render('channels', {to: 'channels'})
        @render('messages')

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
      Meteor.subscribe 'publicChannels'

  @route 'user',
    path: 'users/:user'
    layoutTemplate: 'main_layout'
    loadingTemplate: 'loading'
    template: 'user_profile'
    waitOn: ->
      Meteor.subscribe 'publicChannels'
    data: ->
      Meteor.users.findOne(username: @params.user)

  @route 'channel',
    path: '/channels/:channel'
    layoutTemplate: 'channel_layout'
    template: 'messages'
    yieldTemplates:
      'channels': {to: 'channels'}
      'channelHeader': {to: 'header'}
      'say': {to: 'say'}
      'users': {to: 'users'}
    onBeforeAction: ->
      channel = "##{@params.channel}"
      @render('loading') if not @ready()
      Session.set 'channel', channel
      Meteor.call 'join', Meteor.user().username, channel if Meteor.user()
      @timeAgoInterval = Meteor.setInterval ->
        timeAgoDep.changed()
      , 60000
    onAfterAction: ->
      Session.set("##{@params.channel}.unread", 0)
    onStop: ->
      Meteor.clearInterval @timeAgoInterval
      Session.set 'channel', null
    waitOn: ->
      handlers.messages = \
      Meteor.subscribe 'messages', "##{@params.channel}", PERPAGE * (Session.get('messages.page') + 1)
    data: ->
      {
        channel: Channels.findOne({name: "##{@params.channel}"})
        pm: null
      }
    action: ->
      channel = "##{@params.channel}"
      if @ready()
        if Meteor.user() and Meteor.user().profile.channels[channel]?.kicked
          @render('kicked')
          @render('channels', {to: 'channels'})
          @render('channelHeader', {to: 'header'})
          @render('users', {to: 'users'})
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
    yieldTemplates:
      'channels': {to: 'channels'}
      'channelHeader': {to: 'header'}
    onBeforeAction: ->
      channel = "##{@params.channel}"
      Session.set 'subPage', 'settings'
      Session.set 'channel', channel
    onStop: ->
      Session.set 'subPage', null
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
      Meteor.subscribe 'privateMessages', @params.user, PERPAGE
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

