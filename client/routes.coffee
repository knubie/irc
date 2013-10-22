channelController = (ctx) ->
  if ctx?.params?.channel
    channel = "##{ctx.params.channel}"
    Session.set 'page', 'loading'
    Session.set 'channel.name', channel
    Session.set 'messages.page', 1
    # Join channel if not already in it.
    if channel not in Meteor.user()?.profile.channels
      Meteor.call 'join', Meteor.user().username, channel
    # Wait until this stuff is ready before changing page.
    Deps.autorun ->
      if handlers.joinedChannels.ready() and scrollToPlace?
        Session.set('page', 'channel')

page '/', ->
  Session.set 'channel.name', 'all'
  Session.set 'channel.id', null
  Session.set 'messages.page', 1
  Session.set 'page', 'home'

page '/login', ->
  if Meteor.user()
    page('/')
  else
    Session.set('page', 'login')


page '/channels/:channel', (ctx) ->
  channelController(ctx)

page '/channels/:channel/mentions', (ctx) ->
  if ctx?.params?.channel
    channel = "##{ctx.params.channel}"
    Session.set 'channel.name', channel
  Session.set('page', 'mentions')

page '/channels/:channel/settings', (ctx) ->
  if ctx?.params?.channel
    channel = "##{ctx.params.channel}"
    Session.set 'channel.name', channel
  Session.set('page', 'settings')

do page
