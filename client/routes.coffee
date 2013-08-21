########## Iron Router ##########
#TODO: standardize all template names, session variables, and data contexts.
#Router.map ->
  #@route 'home',
    #path: '/'
    #template: 'channel_main'
    #data: ->
      #Session.set 'channel.name', 'all'
      #Session.set 'channel.id', null
      #{}
  #@route 'explore'
  #@route 'notification_request'
  #@route 'login',
    #template: 'sign_in'
  #@route 'logout' # Is this even needed?
  #@route 'channel_settings',
    #path: '/channels/:channel/settings'
    #data: ->
      #Session.set 'channel.name', @params.channel
      #Session.set 'channel.id', Channels.findOne({name: @params.channel})._id
      #{}
  #@route 'channel_users',
    #path: '/channels/:channel/users'
    #data: ->
      #Session.set 'channel.name', @params.channel
      #Session.set 'channel.id', Channels.findOne({name: @params.channel})._id
      #{}
  #@route 'users',
    #template: 'user_profile'
    #path: '/users/:user'

########## Old Router ##########
Meteor.Router.filters
  'checkLoggedIn': (page) ->
    if Meteor.loggingIn()
      return 'loading'
    else if Meteor.user()
      return page
    else
      return 'home_logged_out'
  'waitForMessages': (page) ->
    if handlers.messages.ready()
      return page
    else
      return 'loading'

Meteor.Router.add
  '/': ->
    if Meteor.user()
      Session.set 'channel.name', 'all'
      Session.set 'channel.id', null
      return 'channel_main'
    else
      return 'home_logged_out'
  '/explore': 'explore'
  '/notifications-request': 'notification_request'
  '/login': ->
    if Meteor.user()?
      Meteor.Router.to('/')
    else
      return 'sign_in'
  '/logout': ->
    Meteor.call 'disconnect', Meteor.user().username
    Meteor.logout ->
      Meteor.Router.to('/')
  '/channels/:channel': (channel) ->
    if ch = Channels.findOne(name:"##{channel}")
      Session.set 'scroll', 0
      Session.set 'channel.name', ch.name
      Session.set 'channel.id', ch._id
      #handlers.messages[ch.name].reset()
      return 'channel_main'
    else
      return 'not_found'
    #TODO: no such channel
  '/channels/:channel/settings': (channel) ->
    if ch = Channels.findOne(name:"##{channel}")
      Session.set 'channel.name', ch.name
      Session.set 'channel.id', ch._id
      return 'channel_settings'
    else
      return 'not_found'
    #else
    # no such channel
  '/channels/:channel/users': (channel) ->
    if ch = Channels.findOne(name:"##{channel}")
      Session.set 'channel.name', ch.name
      Session.set 'channel.id', ch._id
      return 'channel_users'
    else
      return 'not_found'
  '/users/:username': (username) ->
    Session.set 'user_profile', Meteor.users.findOne({username})?._id
    return 'user_profile'


  '*': 'not_found'

Meteor.Router.filter 'checkLoggedIn', except: [
  'sign_in'
  'channel_main'
  'channel_users'
  'not_found'
  'user_profile'
  'explore'
]
#Meteor.Router.filter 'waitForMessages', only: 'channel_main'
#TODO: add filter for sign in page to show signing in
