
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

Template.channels.helpers
  channels: ->
    if Meteor.user()
      (channel for channel of Meteor.user().profile.channels)
    else
      [Session.get('channel.name')]
    #Channels.find
      #name: $in: (channel for channel of Meteor.user().profile.channels)
    #.fetch()
  all: ->
    if Session.equals 'channel.name', 'all' then 'selected' else ''

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
    Meteor.call 'topic', Meteor.user(), Session.get('channel.id'), topic
    $('.topic').show()
    $('#topic-form').hide()

Template.channel_header.helpers
  channel: ->
    Session.get 'channel.name'
  url_channel: ->
    Session.get('channel.name').match(/^(#)?(.*)$/)[2]
  users: ->
    if Session.get('channel.name').isChannel()
      Channels.findOne(Session.get 'channel.id')?.users
  topic: ->
    if Session.get('channel.name').isChannel()
      Channels.findOne(Session.get 'channel.id')?.topic
  op_status: ->
    if Session.get('channel.name').isChannel() and Meteor.user()
      Channels.findOne(Session.get 'channel.id')?.nicks[Meteor.user().username] is '@'
    else
      return no

########## Channel ##########

Template.channel.events
  'click a': (e,t) ->
    $('.channel-container').show()
    $('#say-input').focus() unless Modernizr.touch

  'click .close': ->
    Meteor.call 'part', Meteor.user().username, "#{@}"
    Session.set 'channel.name', 'all'
    Session.set 'channel.id', null
    Meteor.Router.to('/')

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
