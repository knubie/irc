Router.map ->
  @route 'home',
    path: '/'
    layoutTemplate: 'main_layout'
    loadingTemplate: 'loading'
    template: 'home'
    before: ->
      Session.set 'subPage', 'messages'
    waitOn: ->
      if Meteor.user()
        limit = (PERPAGE * Session.get('messages.page'))
        channels = (channel for channel of Meteor.user().profile.channels)
        Meteor.subscribe 'messages', channels, limit
      else
        return {ready: -> true}
    data: ->
      {
        channel: null
        pm: null
        subpage: 'messages'
      }

  @route 'login',
    layoutTemplate: 'main_layout'

  @route 'account',
    layoutTemplate: 'main_layout'
    data: Meteor.user()

  @route 'explore',
    layoutTemplate: 'main_layout'
    loadingTemplate: 'loading'
    waitOn: ->
      Meteor.subscribe 'publicChannels'

  @route 'users/:user',
    layoutTemplate: 'main_layout'
    loadingTemplate: 'loading'
    template: 'user_profile'
    waitOn: ->
      Meteor.subscribe 'publicChannels'
    data: ->
      Meteor.users.findOne(username: @params.user)

  @route 'channelPage',
    path: '/channels/:channel'
    layoutTemplate: 'main_layout'
    loadingTemplate: 'loading'
    before: ->
      channel = "##{@params.channel}"
      Session.set 'subPage', 'messages'
      if Meteor.user() and not Meteor.user().profile.channels[channel]?
        Meteor.call 'join', Meteor.user().username, channel
    waitOn: ->
      handlers.messages = \
      Meteor.subscribe 'messages', "##{@params.channel}", PERPAGE
    data: ->
      {
        channel: Channels.findOne({name: "##{@params.channel}"})
        pm: null
        subpage: 'messages'
      }

  @route 'mentions',
    path: '/channels/:channel/mentions'
    template: 'channelPage'
    layoutTemplate: 'main_layout'
    loadingTemplate: 'loading'
    before: ->
      Session.set 'subPage', 'mentions'
    waitOn: ->
      handlers.messages = \
      Meteor.subscribe 'mentions', "##{@params.channel}", PERPAGE
    data: ->
      {
        channel: Channels.findOne({name: "##{@params.channel}"})
        pm: null
        subpage: 'mentions'
      }

  @route 'channelSettings',
    path: '/channels/:channel/settings'
    template: 'channelPage'
    layoutTemplate: 'main_layout'
    loadingTemplate: 'loading'
    before: ->
      Session.set 'subPage', 'settings'
    data: ->
      {
        channel: Channels.findOne({name: "##{@params.channel}"})
        pm: null
        subpage: 'settings'
      }

  @route 'messages',
    path: '/messages/:user'
    template: 'channelPage'
    layoutTemplate: 'main_layout'
    loadingTemplate: 'loading'
    before: ->
      Session.set 'subPage', 'messages'
      {pms} = Meteor.user().profile
      pms[@params.user] = {unread: 0} unless @params.user of pms
      Meteor.users.update Meteor.userId(), $set: {'profile.pms': pms}
    waitOn: ->
      handlers.messages = \
      Meteor.subscribe 'privateMessages', @params.user, PERPAGE
    data: ->
      {
        channel: null
        pm: @params.user
        subpage: 'messages'
      }

shit = (page) ->
  controller = (opts) ->
    Deps.autorun (c) ->
      if not opts.handler? or opts.handler.ready()
        if not opts.msgHandler? or opts.msgHandler.ready()
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
        Session.set 'pm', null

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
      #msgHandler: do ->
        #handlers.messages[channel] ? Meteor.subscribe 'messages', channel, PERPAGE
      handler: do ->
        if Meteor.user()?
          handlers.joinedChannels
        else
          handlers.publicChannels
      after: ->
        Session.set 'messages.page', 1
        if Meteor.user()? and not Meteor.user()?.profile.channels[channel]?
          Meteor.call 'join', Meteor.user().username, channel
        Session.set 'channel', Channels.findOne({name: channel})._id
        Session.set 'subPage', 'messages'
        Session.set 'pm', null
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
        Session.set 'channel', Channels.findOne({name: channel})._id
        Session.set 'subPage', 'settings'
      page: ->
        if channelDoc = Channels.findOne({name: channel})
          'channel'
        else
          'notFound'

  page '/channels/:channel/mentions', (ctx) ->
    channel = "##{ctx.params.channel}"
    console.log 'mentions route.'
    limit = (PERPAGE * Session.get('messages.page'))
    handlers.mentions[channel] = Meteor.subscribe 'mentions', channel, limit
    controller
      handler: handlers.mentions[channel]
      after: ->
        Session.set 'channel', Channels.findOne({name: channel})._id
        Session.set 'subPage', 'mentions'
        console.log 'after'
      page: ->
        if channelDoc = Channels.findOne({name: channel})
          'channel'
        else
          'notFound'

  page '/users/:user', (ctx) ->
    controller
      after: -> Session.set('user_profile', Meteor.users.findOne(username:ctx.params.user))
      handler: handlers.publicChannels
      page: -> 'userProfile'

  page '/messages/:user', (ctx) ->
    controller
      after: ->
        if Meteor.user()
          if Meteor.user().profile.pms?
            {pms} = Meteor.user().profile
          else
            pms = {}
          pms[ctx.params.user] = {unread: 0} unless ctx.params.user of pms
          # Update the User with the new PMs object.
          Meteor.users.update Meteor.userId(), $set: {'profile.pms': pms}
          Session.set 'messages.page', 1
          Session.set 'subPage', 'messages'
          Session.set 'channel', null
          Session.set 'pm', ctx.params.user
      page: -> 'channel'
  do page
