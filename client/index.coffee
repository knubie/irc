#TODO: write a helper function for setting cannel session

########## Global helpers ##########

Handlebars.registerHelper 'all', ->
  Session.equals 'channel.name', 'all'

Template.home_logged_out.events
  'submit #signup': (e,t) ->
    e.preventDefault()
    username = t.find('#auth-nick').value
    email = t.find('#auth-email').value
    password = t.find('#auth-pw').value
    _id = Accounts.createUser {username, email, password, profile:
      connection: off
      account: 'free'
      channels: {}
    }, (error) ->
      if error
        alert error.reason
      else
        Meteor.call 'remember', username, password, Meteor.userId()
        if window.webkitNotifications.checkPermission() is 1
          Meteor.Router.to('/notifications-request') #FIXME: should work without this.
        else
          Meteor.Router.to('/') #FIXME: should work without this.

Template.sign_in.events
  'submit #signin': (e,t) ->
    e.preventDefault()
    username = t.find('#signin-username').value
    password = t.find('#signin-password').value
    Meteor.loginWithPassword username, password, (error) ->
      if error
        alert error.reason
      else
        Meteor.call 'connect', username, password, Meteor.userId()
        if window.webkitNotifications.checkPermission() is 1
          Meteor.Router.to('/notifications-request') #FIXME: should work without this.
        else
          Meteor.Router.to('/') #FIXME: should work without this.

########## Notification Request ##########
#
Template.notification_request.rendered = ->
  document.querySelector('.allow-notifications').addEventListener 'click', ->
    webkitNotifications.requestPermission()
    Meteor.Router.to('/')

########## Say ##########

Template.say.events
  'keydown #say': (e, t) ->
    keyCode = e.keyCode or e.which
    if keyCode is 13
      e.preventDefault()
      message = t.find('#say-input').value
      $('#say-input').val('')
      Meteor.call 'say', Meteor.user().username, Session.get('channel.name'), message
      user = Meteor.user()
      convo = ''
      channelDoc = Channels.findOne(Session.get('channel.id'))
      for nick of channelDoc.nicks
        if regex.nick(nick).test(message)
          convo = nick
          break

        status =
          '@': 'operator'
          '': 'normal'

      Messages.insert
        from: user.username
        channel: Session.get('channel.name')
        text: message
        time: new Date
        owner: Meteor.userId()
        convo: convo
        status: if channelDoc.nicks? then status[channelDoc.nicks[user.username]] else 'normal'
        read: true

Template.say.rendered = ->
  $('#say-input').focus()

########## Users ##########

Template.users.helpers
  users: ->
    (nick for nick of Channels.findOne(Session.get('channel.id')).nicks).sort()

##### logout ######
Template.header.events
  'click .signout': ->
    Meteor.call 'disconnect', Meteor.user().username
    Meteor.logout ->
      Router.go '/'
########## User Profile ##########

Template.user_profile.helpers
  user: -> Meteor.users.findOne(Session.get('user_profile'))
  joined: ->
    console.log @
    moment(@createdAt).format('MMMM Do YYYY')
  channels: ->
    (channel for channel of @profile.channels)
  topic: ->
    Channels.findOne({name: "#{@}"}).topic
  channel_url: ->
    @match(/^(.)(.*)$/)[2]
