controller = (opts) ->
  Deps.autorun (c) ->
    if not opts.handler? or opts.handler.ready()
      opts.after?()
      Session.set 'page', opts.page()
      c.stop()

page '/', ->
  controller
    page: ->
      if Meteor.user()
        'channel'
      else
        'home'
    after: ->
        Session.set 'subPage', 'messages'
        Session.set 'channel', null

page '/login', ->
  controller
    page: -> 'login'
    after: -> page('/') if Meteor.user()

page '/explore', ->
  controller
    handler: handlers.publicChannels
    page: -> 'explore'

page '/account', ->
  controller
    page: -> 'account'

page '/channels/:channel', (ctx) ->
  channel = "##{ctx.params.channel}"
  controller
    handler: do ->
      if Meteor.user()?
        handlers.joinedChannels
      else
        handlers.publicChannels
    after: ->
      Session.set 'messages.page', 1
      if Meteor.user()? and not Meteor.user()?.profile.channels[channel]?
        Meteor.call 'join', Meteor.user().username, channel
      Session.set 'channel', Channels.findOne({name: channel})
      Session.set 'subPage', 'messages'
    page: ->
      if Meteor.user()?
        'channel'
      else
        if channelDoc = Channels.findOne({name: channel})
          'channel'
        else
          'notFound'

page '/channels/:channel/settings', (ctx) ->
  channel = "##{ctx.params.channel}"
  controller
    handler: do ->
      if Meteor.user()? then handlers.joinedChannels else handlers.publicChannels
    after: ->
      Session.set 'channel', Channels.findOne({name: channel})
      Session.set 'subPage', 'settings'
    page: ->
      if channelDoc = Channels.findOne({name: channel})
        'channel'
      else
        'notFound'

page '/channels/:channel/mentions', (ctx) ->
  channel = "##{ctx.params.channel}"
  controller
    handler: handlers.mentions[channel]
    after: ->
      Session.set 'channel', Channels.findOne({name: channel})
      Session.set 'subPage', 'mentions'
    page: ->
      if channelDoc = Channels.findOne({name: channel})
        'channel'
      else
        'notFound'

do page
