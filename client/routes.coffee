########## Iron Router ##########

Router.configure
  layout: 'layout'
  notFoundTemplate: 'not_found'
  loadingTemplate: 'loading'
  #FIXME: the loading template shows up on the home page.
  renderTemplates:
    'header': to: 'header'

Router.map ->
  @route 'home',
    path: '/'
    controller: 'HomeController'
    waitOn: ->
      handlers.messages.all
    data: -> {name: 'all'}
    onBeforeRun: ->
      Session.set 'channel.name', 'all'
      Session.set 'channel.id', null
      Session.set 'messages.page', 1
  @route 'explore'
  @route 'notification_request'
  @route 'login',
    controller: 'LoginController'
  @route 'channel_main',
    path: '/channels/:channel'
    waitOn: ->
      Log.info 'waitOn'
      #FIXME: this doesn't work in firefox.
      channel = "##{@params.channel}"
      if handlers.messages[channel]
        return handlers.messages[channel]
      else
        return handlers.messages[channel] = Meteor.subscribe 'messages', channel, 30
      #handlers.messages[channel] or handlers.messages[channel] = Meteor.subscribe 'messages', channel, 30
      #FIXME: why can't i use ?=
    data: -> Channels.findOne({name: "##{@params.channel}"})
    onBeforeRun: ->
      channel = "##{@params.channel}"
      if Meteor.user()
        unless Meteor.user().profile.channels.hasOwnProperty(channel)
          Meteor.call 'join', Meteor.user().username, channel
      Deps.autorun =>
        Log.info 'onBeforeRun autorun'
        if ch = Channels.findOne({name: channel})
          Session.set 'channel.name', ch.name
          Session.set 'channel.id', ch._id
      Session.set 'messages.page', 1
  @route 'pms_main',
    template: 'channel_main'
    path: '/messages/:user'
    data: -> {name: @params.user}
    onBeforeRun: ->
      #channel = "##{@params.channel}"
      #if Meteor.user()
        #unless Meteor.user().profile.channels.hasOwnProperty(channel)
          #Meteor.call 'join', Meteor.user().username, channel
      Session.set 'channel.name', @params.user
      #Deps.autorun =>
        #if u = Meteor.users.findOne({username: @params.user})
          #Session.set 'channel.name', u.name
          ##Session.set 'channel.id', u._id
      Session.set 'messages.page', 1

  @route 'channel_settings',
    path: '/channels/:channel/settings'
    data: -> Channels.findOne({name: "##{@params.channel}"})
    onBeforeRun: ->
      #FIXME: wait for Channel sub
      Deps.autorun =>
        if ch = Channels.findOne({name: "##{@params.channel}"})
          Session.set 'channel.name', ch.name
          Session.set 'channel.id', ch._id
    #data: ->
      #Session.set 'channel.name', @params.channel
      #Session.set 'channel.id', Channels.findOne({name: @params.channel})._id
      #{}
  @route 'channel_users',
    path: '/channels/:channel/users'
    data: -> Channels.findOne({name: "##{@params.channel}"})
    onBeforeRun: ->
      #FIXME: wait for Channel sub
      Deps.autorun =>
        if ch = Channels.findOne({name: "##{@params.channel}"})
          Session.set 'channel.name', ch.name
          Session.set 'channel.id', ch._id
    #data: ->
      #Session.set 'channel.name', @params.channel
      #Session.set 'channel.id', Channels.findOne({name: @params.channel})._id
      #{}
  @route 'user_profile',
    path: '/users/:username'
    data: -> Meteor.users.findOne({username: @params.username})
    onBeforeRun: ->
      {username} = @params
      Session.set 'user_profile', Meteor.users.findOne({username})?._id
  @route 'account',
    path: '/account'
    data: -> Meteor.user()

class @LoginController extends RouteController
  run: ->
    if Meteor.user()
      Router.go 'home'
    else
      @render 'sign_in' #TODO: change this name
      @render
        'header': to: 'header'

class @ChannelController extends RouteController
  run: ->
    if Meteor.user()
      unless Meteor.user().profile.channels.hasOwnProperty(channel)
        Meteor.call 'join', Meteor.user().username, channel
        @render 'channel_main'
        @render
          'header': to: 'header'

class @HomeController extends RouteController
  #renderTemplates:
    #'channel_header': to: 'channel_header'
    #'channels': to: 'channels'

  run: ->
    if Meteor.user()
      @render 'channel_main'
      @render
        'header': to: 'header'
    else
      @render 'home_logged_out'
      @render
        'header': to: 'header'
