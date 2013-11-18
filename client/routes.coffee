Router.map ->
  @route 'home',
    path: '/'
    layoutTemplate: 'main_layout'
    loadingTemplate: 'loading'
    before: ->
      Session.set 'subPage', 'messages'
    waitOn: ->
      if Meteor.user()
        limit = (PERPAGE * Session.get('messages.page'))
        channels = (channel for channel of Meteor.user().profile.channels)
        Meteor.subscribe 'messages', channels, limit
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
        @render 'channelPage'
      else
        @render 'home'

  @route 'login',
    layoutTemplate: 'main_layout'

  @route 'account',
    layoutTemplate: 'main_layout'
    data: Meteor.user()

  @route 'explore',
    layoutTemplate: 'main_layout'
    loadingTemplate: 'loading'
    waitOn: ->
      Meteor.subscribe 'publicChannels'

  @route 'users/:user',
    layoutTemplate: 'main_layout'
    loadingTemplate: 'loading'
    template: 'user_profile'
    waitOn: ->
      Meteor.subscribe 'publicChannels'
    data: ->
      Meteor.users.findOne(username: @params.user)

  @route 'channelPage',
    path: '/channels/:channel'
    layoutTemplate: 'main_layout'
    loadingTemplate: 'loading'
    before: ->
      channel = "##{@params.channel}"
      Session.set 'subPage', 'messages'
      if Meteor.user() and not Meteor.user().profile.channels[channel]?
        Meteor.call 'join', Meteor.user().username, channel
    waitOn: ->
      Meteor.subscribe 'messages', "##{@params.channel}", PERPAGE
    data: ->
      {
        channel: Channels.findOne({name: "##{@params.channel}"})
        pm: null
        subpage: 'messages'
      }

  @route 'mentions',
    path: '/channels/:channel/mentions'
    template: 'channelPage'
    layoutTemplate: 'main_layout'
    loadingTemplate: 'loading'
    before: ->
      Session.set 'subPage', 'mentions'
    waitOn: ->
      limit = (PERPAGE * Session.get('messages.page'))
      Meteor.subscribe 'mentions', "##{@params.channel}", limit
    data: ->
      {
        channel: Channels.findOne({name: "##{@params.channel}"})
        pm: null
        subpage: 'mentions'
      }

  @route 'channelSettings',
    path: '/channels/:channel/settings'
    template: 'channelPage'
    layoutTemplate: 'main_layout'
    loadingTemplate: 'loading'
    before: ->
      Session.set 'subPage', 'settings'
    data: ->
      {
        channel: Channels.findOne({name: "##{@params.channel}"})
        pm: null
        subpage: 'settings'
      }
