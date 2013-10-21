channelController = (ctx) ->
  if ctx?.params?.channel
    channel = "##{ctx.params.channel}"
    Session.set 'page', 'loading'
    Session.set 'channel.name', channel
    Session.set 'messages.page', 1
    # Wait until this stuff is ready before changing page.
    Deps.autorun ->
      if handlers.joinedChannels.ready() and scrollToPlace?
        if channel not in Meteor.user()?.profile.channels
          Meteor.call 'join', Meteor.user().username, channel
        Session.set('page', 'channel')

page '/', ->
  Session.set 'channel.name', 'all'
  Session.set 'channel.id', null
  Session.set 'messages.page', 1
  Session.set('page', 'home')

page '/login', ->
  if Meteor.user()
    page('/')
  else
    Session.set('page', 'login')


page '/channels/:channel', (ctx) ->
  channelController(ctx)

do page
