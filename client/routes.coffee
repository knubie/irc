########## Iron Router ##########
#TODO: standardize all template names, session variables, and data contexts.
Router.configure
  layout: 'layout'
  notFoundTemplate: 'not_found'
  loadingTemplate: 'loading'
  renderTemplates:
    'header': to: 'header'

Router.map ->
  @route 'home',
    path: '/'
    template: do -> if Meteor.user() then 'channel_main' else 'home_logged_out'
    waitOn: ->
      handlers.messages.all
    data: -> {name: 'all'}
    onBeforeRun: ->
      Session.set 'channel.name', 'all'
      Session.set 'channel.id', null
  @route 'explore'
  @route 'notification_request'
  @route 'login',
    template: 'sign_in'
  #@route 'logout' # Is this even needed?
  @route 'channel_main',
    path: '/channels/:channel'
    waitOn: ->
      channel = "##{@params.channel}"
      handlers.messages[channel] or handlers.messages[channel] = Meteor.subscribe 'messages', channel, 30
      #FIXME: why can't i use ?=
    data: -> Channels.findOne({name: "##{@params.channel}"})
    onBeforeRun: ->
      Deps.autorun =>
        if ch = Channels.findOne({name: "##{@params.channel}"})
          Session.set 'channel.name', ch.name
          Session.set 'channel.id', ch._id
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
    onBeforeRun: ->
      {username} = @params
      Session.set 'user_profile', Meteor.users.findOne({username})?._id
