########## Global helpers ##########

Handlebars.registerHelper 'isChannel', ->
  Session.get('channel.name').isChannel()

Handlebars.registerHelper 'isAll', ->
  Session.equals 'channel.name', 'all'

Template.home_logged_out.events
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
          Router.go "/channels/#{Session.get('joinAfterLogin').match(/^(.)(.*)$/)[2]}"
        else
          Router.go 'home'

Template.sign_in.events
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
          Router.go "/channels/#{Session.get('joinAfterLogin').match(/^(.)(.*)$/)[2]}"
        else
          Router.go 'home'

########## Notification Request ##########
#
Template.notification_request.rendered = ->
  document.querySelector('.allow-notifications').addEventListener 'click', ->
    webkitNotifications.requestPermission()
    Meteor.Router.to('/')

########## Header ##########

Template.header.events
  'click .signout': ->
    #TODO: create some kind of explicit disconnect.
    #Meteor.call 'disconnect', Meteor.user().username
    Meteor.logout -> Router.go 'home'

########## User Profile ##########

Template.user_profile.helpers
  user: -> Meteor.users.findOne(Session.get('user_profile'))
  joined: ->
    moment(@createdAt).format('MMMM Do YYYY')
  channels: ->
    (channel for channel of @profile.channels)
  topic: ->
    Channels.findOne({name: "#{@}"}).topic
  channel_url: ->
    @match(/^(.)(.*)$/)[2]
