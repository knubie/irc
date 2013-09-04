#Template.channel_main.rendered = ->
  #if window.webkitNotifications.checkPermission() is 1 and not Modernizr.touch
    #$('#notification-modal').modal
      #backdrop: true
      #keyboard: true

Template.channel_main.events
  'click #notification-modal .btn-primary': ->
    webkitNotifications.requestPermission()

Template.channel_header.helpers
  channel: ->
    @name
  url_channel: ->
    @name.match(/^(#)?(.*)$/)[2]
  users: ->
    if @name.isChannel()
      @users
  topic: ->
    if @name.isChannel()
      @topic
  op_status: ->
    if @name.isChannel() and Meteor.user()
      @nicks[Meteor.user().username] is '@'
    else
      return no

Template.channel_header.events
  'click .topic-edit > a': (e, t) ->
    $('.topic').hide()
    $('#topic-form').show()
    $('#topic-name').focus()

  'click #topic-form > .cancel': (e, t) ->
    e.preventDefault()
    $('.topic').show()
    $('#topic-form').hide()

  'submit #topic-form': (e,t) ->
    e.preventDefault()
    topic = t.find('#topic-name').value
    Meteor.call 'topic', Meteor.user(), @_id, topic
    $('.topic').show()
    $('#topic-form').hide()

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
    name = "#" + t.find('.new-channel-input').value
    t.find('.new-channel-input').value = ''
    if name
      Meteor.call 'join', Meteor.user().username, name, (err, channelId) ->
        if channelId
          Router.go "/channels/#{name.match(/^(.)(.*)$/)[2]}"
          $('#say-input').focus()

Template.channels.helpers
  channels: ->
    if Meteor.user()
      (channel for channel of Meteor.user().profile.channels)
    else
      [Session.get('channel.name')]
    #Channels.find
      #name: $in: (channel for channel of Meteor.user().profile.channels)
    #.fetch()
  pms: ->
    (pm for pm of Meteor.user().profile.pms)
  all: ->
    if Session.equals 'channel.name', 'all' then 'selected' else ''

########## Channel ##########

Template.channel.events
  'click a': (e,t) ->
    $('.channel-container').show()
    $('#say-input').focus() unless Modernizr.touch

  'click .close': ->
    Meteor.call 'part', Meteor.user().username, "#{@}"
    if "#{@}" is Session.get('channel.name')
      Router.go('home')

Template.channel.helpers
  selected: ->
    if Session.equals 'channel.name', "#{@}" then 'selected' else ''
  private: ->
    ch = Channels.findOne(name: "#{@}")
    if ch?
      's' in ch.modes or 'i' in ch.modes
    else
      no
  url_name: ->
    "#{@}".match(/^(.)(.*)$/)[2]
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

Template.pm.helpers
  selected: ->
    if Session.equals 'channel.name', "#{@}" then 'selected' else ''
  unread: ->
    console.log "#{@}"
    Messages.find
      channel: "#{@}"
      read: false
    .fetch().length or ''
  #unread_mentions: ->
    #if Meteor.user()
      #ignore_list = Meteor.user().profile.channels["#{@}"].ignore
      #Messages.find
        #channel: "#{@}"
        #read: false
        #convo: Meteor.user().username
        #from: $nin: ignore_list
      #.fetch().length or ''
    #else
      #return ''
Template.pm.events
  'click .close': ->
    console.log 'close pm'
    {pms} = Meteor.user().profile
    delete pms["#{@}"]
    Meteor.users.update Meteor.userId(), $set: {'profile.pms': pms}
    if "#{@}" is Session.get('channel.name')
      Router.go('home')
