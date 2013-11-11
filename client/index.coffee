########## Global helpers ##########

Handlebars.registerHelper 'session', (input) ->
  Session.get input

Handlebars.registerHelper 'page', (page) ->
  if Session.equals 'page', page
    Template._page

Handlebars.registerHelper 'subPage', (page) ->
  if Session.equals 'subPage', page
    Template._page

Handlebars.registerHelper 'pageIsHome', ->
  Session.equals 'page', 'home'

Handlebars.registerHelper 'pageIsLogin', ->
  Session.equals 'page', 'login'

Handlebars.registerHelper 'pageIsChannel', ->
  Session.equals('page', 'channel')

Handlebars.registerHelper 'pageIsMentions', ->
  Session.equals('page', 'mentions')

Handlebars.registerHelper 'pageIsLoading', ->
  Session.equals 'page', 'loading'

Handlebars.registerHelper 'pageIsSettings', ->
  Session.equals 'page', 'settings'

Handlebars.registerHelper 'isChannel', ->
  Session.get('channel.name').isChannel()

Handlebars.registerHelper 'isAll', ->
  Session.equals 'channel.name', 'all'

########## Home / Login ##########

Template.home.events
  'click #signup-with-github': (e,t) ->
    console.log 'sign up with github'
    Meteor.loginWithGithub (error) ->
      console.log error if error

  'submit #signup': (e,t) ->
    e.preventDefault()
    # Get credentials from the form
    username = t.find('#auth-nick').value
    email = t.find('#auth-email').value
    password = t.find('#auth-pw').value
    # Create a new user
    _id = Accounts.createUser {username, email, password}, (error) ->
      if error
        alert error.reason
      else
        # Add account to hector
        Meteor.call 'remember', username, password, Meteor.userId()
        if Session.get('joinAfterLogin')
          channel = Session.get('joinAfterLogin').match(/^(.)(.*)$/)[2]
        else
          channel = 'welcome'
        Router.go 'channelPage', {channel}

Template.login.events
  'submit #signin': (e,t) ->
    e.preventDefault()
    username = t.find('#signin-username').value
    password = t.find('#signin-password').value
    Meteor.loginWithPassword username, password, (error) ->
      if error
        alert error.reason
      else
        if Meteor.user().profile.connection is off
          Meteor.call 'connect', username, Meteor.userId()
        if Session.get('joinAfterLogin')
          channel = Session.get('joinAfterLogin').match(/^(.)(.*)$/)[2]
          Router.go 'channelPage', {channel}
        else
          Router.go 'home'

Template.login.rendered = ->
  #FIXME: this doesn't work.
  $(@find('#signin-username')).focus()

########## Notification Request ##########
#
Template.notification_request.rendered = ->
  document.querySelector('.allow-notifications').addEventListener 'click', ->
    webkitNotifications.requestPermission()
    Router.go 'home'

########## Header ##########

Template.header.events
  'click .signout': ->
    #TODO: create some kind of explicit disconnect.
    #Meteor.call 'disconnect', Meteor.user().username
    Meteor.logout -> Router.go 'home'

Template.header.helpers
  username: ->
    Meteor.user().username

########## User Profile ##########

Template.user_profile.helpers
  joined: ->
    moment(@createdAt).format('MMMM Do YYYY')
  channels: ->
    (channel for channel of @profile.channels)
  topic: ->
    Channels.findOne({name: "#{@}"}).topic
  channel_url: ->
    @match(/^(.)(.*)$/)[2]
