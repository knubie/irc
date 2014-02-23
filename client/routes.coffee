Router.map ->
  @route 'home',
    path: '/'
    layoutTemplate: do ->
      if Meteor.user()
        'channel_layout'
      else
        'main_layout'
    loadingTemplate: 'loading'
    before: ->
      Session.set 'subPage', 'messages'
      if Meteor.user()
        @layoutTemplate = 'channel_layout'
      else
        @layoutTemplate = 'main_layout'
    waitOn: ->
      if Meteor.user()
        channels = (channel for channel of Meteor.user().profile.channels)
        Meteor.subscribe 'messages', channels, PERPAGE
      else
        return {ready: -> true}
    data: ->
      {
        channel: null
        pm: null
        subpage: 'messages'
      }
    action: ->
      if Meteor.user()
        @render('channels', {to: 'channels'})
        @render('messages')
      else
        @render()

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
    loadingTemplate: 'loading'
    layoutTemplate: 'channel_layout'
    template: 'messages'
    yieldTemplates:
      'channels': {to: 'channels'}
      'channelHeader': {to: 'header'}
      'say': {to: 'say'}
      'users': {to: 'users'}
    before: ->
      channel = "##{@params.channel}"
      Session.set 'channel', channel
      if Meteor.user() and
      not Meteor.user().profile.channels[channel]?
        Meteor.call 'join', Meteor.user().username, channel
    unload: ->
      Session.set 'channel', null
    waitOn: ->
      handlers.messages = \
      Meteor.subscribe 'messages', "##{@params.channel}", PERPAGE * Session.get('messages.page')
    data: ->
      {
        channel: Channels.findOne({name: "##{@params.channel}"})
        pm: null
      }
    action: ->
      channel = "##{@params.channel}"
      if Meteor.user() and Meteor.user().profile.channels[channel].kicked
        @render('kicked')
        @render('channels', {to: 'channels'})
        @render('channelHeader', {to: 'header'})
        @render('users', {to: 'users'})
      else
        @render()

  @route 'mentions',
    path: '/channels/:channel/mentions'
    template: 'mentions'
    layoutTemplate: 'channel_layout'
    loadingTemplate: 'loading'
    yieldTemplates:
      'channels': {to: 'channels'}
      'channelHeader': {to: 'header'}
    before: ->
      channel = "##{@params.channel}"
      Session.set 'subPage', 'mentions'
      Session.set 'channel', channel
    unload: ->
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
    before: ->
      channel = "##{@params.channel}"
      Session.set 'subPage', 'settings'
      Session.set 'channel', channel
    unload: ->
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
    after: ->
      Session.set 'subPage', 'messages'
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
