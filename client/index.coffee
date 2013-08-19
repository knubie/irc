#TODO: write a helper function for setting cannel session

########## Global helpers ##########

Handlebars.registerHelper 'all', ->
  Session.equals 'channel.name', 'all'

Template.home_logged_out.events
  'submit #form-signup': (e,t) ->
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
  'submit #form-signin': (e,t) ->
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

########## Channels ##########

Template.channels.events
  'click .new-channel-link': (e, t) ->
    $('.new-channel-link').hide()
    $('.new-channel-form').show()
    $('.new-channel-input').focus()

  'blur .new-channel-input': (e, t) ->
    $('.new-channel-link').show()
    $('.new-channel-form').hide()

  'keydown .new-channel-input': (e, t) ->
    keyCode = e.keyCode or e.which
    if keyCode is 27
      $('.new-channel-link').show()
      $('.new-channel-form').hide()

  'submit .new-channel-form': (e, t) ->
    e.preventDefault()
    name = t.find('.new-channel-input').value
    t.find('.new-channel-input').value = ''
    if name
      Meteor.call 'join', Meteor.user().username, name, (err, channelId) ->
        if channelId
          Session.set 'channel.id', channelId
          Session.set 'channel.name', name
          $('#say-input').focus()

  'click .channel > a': (e,t) ->
    ch = Channels.findOne {name: "#{@}"}
    Session.set 'scroll', false
    handlers.messages.reset()
    Session.set 'channel.name', "#{@}"
    Session.set 'channel.id', ch._id
    $('#say-input').focus()

  'click .close': ->
    Meteor.call 'part', Meteor.user().username, "#{@}"
    Session.set 'channel.name', 'all'
    Session.set 'channel.id', null
    Meteor.Router.to('/')

Template.channels.helpers
  channels: ->
    if Meteor.user()
      (channel for channel of Meteor.user().profile.channels)
    else
      [Session.get('channel.name')]
    #Channels.find
      #name: $in: (channel for channel of Meteor.user().profile.channels)
    #.fetch()
  unread: ->
    if Meteor.user()
      ignore_list = Meteor.user().profile.channels["#{@}"].ignore
      Messages.find
        channel: "#{@}"
        read: false
        from: $nin: ignore_list
      .fetch().length or ''
    else
      return ''
  unread_mentions: ->
    if Meteor.user()
      ignore_list = Meteor.user().profile.channels["#{@}"].ignore
      Messages.find
        channel: "#{@}"
        read: false
        convo: Meteor.user().username
        from: $nin: ignore_list
      .fetch().length or ''
    else
      return ''
  selected: ->
    if Session.equals 'channel.name', "#{@}" then 'selected' else ''
  all: ->
    if Session.equals 'channel.name', 'all' then 'selected' else ''
  url_name: ->
    "#{@}".match(/^(.)(.*)$/)[2]
  private: ->
    ch = Channels.findOne(name: "#{@}")
    if ch?
      's' in ch.modes or 'i' in ch.modes
    else
      no

Template.channel_header.helpers
  channel: ->
    Session.get 'channel.name'
  url_channel: ->
    Session.get('channel.name').match(/^(#)?(.*)$/)[2]
  users: ->
    if Session.get('channel.name').isChannel()
      Channels.findOne(Session.get 'channel.id')?.users

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
      #TODO: use channel.id insted
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

########## User Profile ##########

Template.user_profile.data = Meteor.users.findOne(Session.get('user_profile'))
