########## Global helpers ##########

Handlebars.registerHelper 'session', (input) ->
  Session.get input

########## Home / Login ##########

Template.signup.events
  'submit #signup': (e,t) ->
    e.preventDefault()
    username = t.find('#signup-username').value
    email = t.find('#signup-email').value
    password = t.find('#signup-password').value
    _id = Accounts.createUser {username, email, password}, (error) ->
      if error
        alert error.reason
      else
        # Add account to hector
        Meteor.call 'remember', username, password, Meteor.userId()
        if Session.get('joinAfterLogin')
          channel = Session.get('joinAfterLogin').match(/^(.)(.*)$/)[2]
          Router.go 'channel', {channel}
        else
          Router.go 'home'

  'click #signup-with-github': (e,t) ->
    console.log 'sign up with github'
    Meteor.loginWithGithub (error) ->
      console.log error if error

Template.signup.rendered = ->
  $(@find('#signup-email')).focus()

Template.login.events
  'submit #signin': (e,t) ->
    e.preventDefault()
    username = t.find('#signin-username').value
    password = t.find('#signin-password').value
    Meteor.loginWithPassword username, password, (error) ->
      if error
        alert error.reason
      else
        if Session.get('joinAfterLogin')
          channel = Session.get('joinAfterLogin').match(/^(.)(.*)$/)[2]
          Router.go 'channel', {channel}
        else
          Router.go 'home'

Template.login.rendered = ->
  $(@find('#signin-username')).focus()

########## Header ##########

Template.header.events
  'click .signout': ->
    #TODO: create some kind of explicit disconnect.
    #Meteor.call 'disconnect', Meteor.user().username
    Meteor.logout -> Router.go 'home'

Template.header.helpers
  username: ->
    Meteor.user().username
  home: ->
    if Meteor.user()?
      return ''
    else
      return 'home'
  channel: ->
    if Session.get('channel')
      return 'hidden-xs'
    else
      return ''

Template.notifications.helpers
  hide: ->
    (Modernizr.touch and $(window).width() < 769) or
    not Meteor.user() or
    Notification.permission isnt 'default' or
    Meteor.user().profile.notifications is off

Template.notifications.events
  'click .enable': (e,t) ->
    e.preventDefault()
    Notification.requestPermission()
    $('.request-notifications-container').fadeOut(200)
  'click .hide-me': (e,t) ->
    e.preventDefault()
    Meteor.users.update(Meteor.userId(), $set: 'profile.notifications': false)
    $('.request-notifications-container').fadeOut(200)


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
