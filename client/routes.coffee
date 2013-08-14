Meteor.Router.filters
  'checkLoggedIn': (page) ->
    if Meteor.loggingIn()
      return 'loading'
    else if Meteor.user()
      return page
    else
      return 'home_logged_out'

Meteor.Router.add
  '/': ->
    Session.set 'channel.name', 'all'
    Session.set 'channel.id', null
    return 'channel_main'

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

  '/channels/:channel': (channel) ->
    if ch = Channels.findOne(name:"##{channel}")
      Session.set 'channel.name', ch.name
      Session.set 'channel.id', ch._id
      return 'channel_main'
    else
      Session.set 'channel.name', channel
      return 'channel_main'
    #TODO: no such channel

  '*': 'not_found'

Meteor.Router.filter('checkLoggedIn', except: 'sign_in')
