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

########## Messages ##########

Template.messages.rendered = ->
  if Session.equals 'channel.name', 'all'
    $('.message').hover ->
      $(".message").not("[data-channel='#{$(this).attr('data-channel')}']").addClass 'faded'
    , ->
      $('.message').removeClass 'faded'
  else if Session.get('channel.name').isChannel()
    ch = Channels.findOne Session.get('channel.id')
    nicks = (nick for nick of ch?.nicks) ? []
    #$('#say-input').typeahead
      #name: 'names'
      #local: nicks

  if Session.equals 'scroll', false
    $(window).scrollTop($(document).height() - $(window).height())

Template.messages.events
  'click, tap .load-next': ->
    handlers.messages[Session.get 'channel.name'].loadNextPage()

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

Template.messages.helpers
  messages: ->
    prev = null
    if Session.equals 'channel.name', 'all'
      messages = Messages.find({}, {sort: {time: 1}}).fetch()
    else
      messages = Messages.find(
        channel: Session.get 'channel.name'
      , sort: {time: 1}).fetch()
    setPrev = (msg) ->
      msg.prev = prev
      prev = msg
    if Meteor.user()
      return (setPrev message for message in messages when message.from \
      not in (Meteor.user().profile.channels[message.channel]?.ignore or []))
    else
      return (setPrev message for message in messages)
  topic: ->
    if Session.get('channel.name').isChannel()
      Channels.findOne(Session.get 'channel.id')?.topic
  op_status: ->
    if Session.get('channel.name').isChannel() and Meteor.user()
      Channels.findOne(Session.get 'channel.id')?.nicks[Meteor.user().username] is '@'
    else
      return no
  channel: ->
    Session.get 'channel.name'
  url_channel: ->
    Session.get('channel.name').match(/^(#)?(.*)$/)[2]
  users: ->
    if Session.get('channel.name').isChannel()
      Channels.findOne(Session.get 'channel.id')?.users

########## Message ##########

Template.message.rendered = ->
  # Get message text.
  p = $(@find('p'))
  ptext = p.html()
  # Linkify URLs.
  ptext = ptext.replace regex.url, "<a href='$1' target='_blank'>$1</a>"
  # Linkify nicks.
  if @data.channel.isChannel()
    for nick, status of Channels.findOne(name: @data.channel).nicks
      ptext = ptext.replace regex.nick(nick), "$1<a href=\"#\">$2</a>$3"
  # Markdownify other stuff.
  while regex.code.test ptext
    ptext = ptext.replace regex.code, '$1$2<code>$3</code>$4'
  while regex.bold.test ptext
    ptext = ptext.replace regex.bold, '$1$2<strong>$3</strong>$4'
  while regex.underline.test ptext
    ptext = ptext.replace regex.underline, '$1$2<span class="underline">$3</span>$4'
  p.html(ptext)

  if not @data.read and @data.from
    Messages.update @data._id, $set: {'read': true}

Template.message.events
  'click .reply-action': ->
    $('#say-input').val("@#{@from} ")
    $('#say-input').focus()

  'click .ignore-action': ->
    #TODO: extract this pattern into an update method
    {channels} = Meteor.user().profile
    channels[@channel].ignore.push @from
    channels[@channel].ignore = _.uniq channels[@channel].ignore
    Meteor.users.update Meteor.userId()
    , $set: {'profile.channels': channels}

  'click, tap': (e, t) ->
    if Session.equals 'channel.name', 'all'
      # Slide toggle all messages not belonging to clicked channel
      # and set session to the new channel.
      $messagesFromOtherChannels = \
        $('.message').not("[data-channel='#{@channel}']")
      ch = Channels.findOne {name: @channel}
      # If there are any message to slideToggle...
      if $messagesFromOtherChannels.length > 0
        $messagesFromOtherChannels.slideToggle 400, =>
          Session.set 'channel.name', @channel
          Session.set 'channel.id', ch._id
      else # No messages to slideToggle
        Session.set 'channel.name', @channel
        Session.set 'channel.id', ch._id

  'click .convo': (e, t) ->
    $('.message')
    .not("[data-nick='#{@from}']")
    .not("[data-nick='#{@convo}']")
    .slideToggle 400

  'click .kick': (e, t) ->
    Meteor.call 'kick', Meteor.user(), @channel, @from

Template.message.helpers
  joinToPrev: ->
    unless @prev is null
      @prev.from is @from and @prev.channel is @channel and @type() isnt 'mention' and @prev.type() isnt 'mention'
  isConvo: ->
    if @convo then yes else no
  timeAgo: ->
    moment(@time).fromNow()
  message_class: ->
    if @online() then @type() else "offline #{@type()}"
  op_status: ->
    if @channel.isChannel() and Meteor.user()
      Channels.findOne(name: @channel).nicks[Meteor.user().username] is '@'
  self: ->
    @type() is 'self'

Template.notification.timeAgo = ->
  moment(@time).fromNow()

Template.notification.events
  'click, tap li': ->
    $(window).scrollTop $("##{@_id}").offset().top - 10

  'click .close': ->
    # Do something

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

########## Settings ##########

Template.settings.events
  'submit #ignore-form': (e,t) ->
    e.preventDefault()
    ignoree = t.find('#inputIgnore').value
    t.find('#inputIgnore').value = ''
    {channels} = Meteor.user().profile
    channels[Session.get('channel.name')]?.ignore.push ignoree
    Meteor.users.update Meteor.userId()
    , $set: 'profile.channels': _.uniq channels[Session.get 'channel.name']?.ignore

  'click .close': (e,t) ->
    {channels} = Meteor.user().profile
    index = channels[Session.get('channel.name')]?.ignore.indexOf(@)
    channels[Session.get('channel.name')]?.ignore.splice(index, 1)
    Meteor.users.update \
      Meteor.userId(), $set: {'profile.channels': channels}

  'click #privateCheckbox': (e,t) ->
    channel = Channels.findOne Session.get('channel.id')
    if 's' in channel.modes or 'i' in channel.modes
      Meteor.call 'mode', Meteor.user(), Session.get('channel.name'), '-si'
    else
      Meteor.call 'mode', Meteor.user(), Session.get('channel.name'), '+si'

Template.settings.helpers
  op_status: ->
    if Session.equals 'channel.name', 'all'
      return no
    else
      Channels.findOne(Session.get 'channel.id')?.nicks[Meteor.user().username] is '@'
  ignore_list: ->
    Meteor.user().profile.channels[Session.get('channel.name')]?.ignore
  private_checked: ->
    channel = Channels.findOne Session.get('channel.id')
    if 's' in channel.modes or 'i' in channel.modes
      return 'checked'
    else
      return ''

########## Users ##########

Template.users.helpers
  users: ->
    (nick for nick of Channels.findOne(Session.get('channel.id')).nicks).sort()

########## User Profile ##########

Template.user_profile.data = Meteor.users.findOne(Session.get('user_profile'))
