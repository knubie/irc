#TODO: change Session.set 'channel' to channel.name and channel._id
########## Defaults ##########

# Currently selected channel for viewing messages.
Session.setDefault 'channel', 'all'
# Push messages to the bottom by default (ie don't save scroll position).
Session.setDefault 'scroll', false

########## Subscriptions ##########
handlers = {messages:{},channel:{}}
handlers.user = Meteor.subscribe 'users'
#handlers.messages = Meteor.subscribe 'messages'
handlers.channel = Meteor.subscribe 'channels', ->
  subscribeToMessagesOf = (channel) ->
    handlers.messages[channel.name] = Meteor.subscribeWithPagination 'messages'
    , channel.name
    , 30
  subscribeToMessagesOf channel for channel in Channels.find().fetch()
  subscribeToMessagesOf {name: 'all'}
  Channels.find().observe
    added: subscribeToMessagesOf

#UserStatus.on "sessionLogin", (userId, sessionId, ipAddr) ->
  #user = Meteor.users.findOne userId
  #if user.profile.connection is off

Meteor.startup ->
  $(window).scroll ->
    # If not scrolled to the bottom
    if $(window).scrollTop() < $(document).height() - $(window).height()
      Session.set 'scroll', true
    else
      Session.set 'scroll', false

    # If close to top and messages handler is ready.
    if $(window).scrollTop() <= 50 and handlers.messages[Session.get 'channel'].ready()
      # Load next page.
      handlers.messages[Session.get 'channel'].loadNextPage()

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
      if Meteor.userId()? and not error
        Meteor.call 'remember', username, password, Meteor.userId()

  'submit #form-signin': (e,t) ->
    e.preventDefault()
    username = t.find('#signin-username').value
    password = t.find('#signin-password').value
    Meteor.loginWithPassword username, password, (error) ->
      Meteor.call 'connect', username, password, Meteor.userId()

########## Dashboard ##########

Template.home_logged_in.events
  'click .sign-out': ->
    Meteor.logout()

Template.home_logged_in.rendered = ->
  $(window).on 'keydown', (e) ->
    keyCode = e.keyCode or e.which
    # Focus #say-input on <TAB>
    if keyCode is 9 and not $('#say-input').is(':focus')
      e.preventDefault()
      $('#say-input').focus()

Template.home_logged_in.helpers
  connection: ->
    Meteor.user().profile.connection

########## Channels ##########

Template.channels.events
  'click .new-channel-link': (e, t) ->
    $('.new-channel-link').hide()
    $('#new-channel').show()
    $('#new-channel-name').focus()

  'blur #new-channel-name': (e, t) ->
    $('.new-channel-link').show()
    $('#new-channel').hide()

  'submit #new-channel': (e, t) ->
    e.preventDefault()
    name = t.find('#new-channel-name').value
    t.find('#new-channel-name').value = ''
    Meteor.call 'join', Meteor.user().username, name
    #TODO: combine with identicle lines below?
    Session.set 'channel', name
    $('#say-input').focus()

  'click .channel > a': (e,t) ->
    Session.set 'channel', @name
    $('#say-input').focus()

  'click .close': ->
    Meteor.call 'part', Meteor.user(), @name
    Session.set 'channel', 'all'

Template.channels.helpers
  channels: ->
    #TODO: reduce code
    channels = (channel for channel in Channels.find().fetch() \
      when Meteor.user().username of channel.nicks)

    add_url = (channel) ->
      return channel extends
        url_name: ->
          @name.match(/^(.)(.*)$/)[2]

    channels = (add_url channel for channel in channels)
    #.map (channel) ->
      #channel extends
        #url_name: ->
          #@name.match(/^(.)(.*)$/)[2]

    return channels
      
    #chs = Channels.find().map (doc) ->
      #console.log doc
      #if Meteor.user().username of doc.nicks
        #console.log doc
        #return doc extends
          #url_name: ->
            #@name.match(/^(.)(.*)$/)[2]
    #console.log chs
    #return chs
  selected: ->
    if Session.equals 'channel', @name then 'selected' else ''
  notification_count: ->
    #if @notifications().length < 1 then '' else @notifications().length
    0
  all: ->
    if Session.equals 'channel', 'all' then 'selected' else ''

########## Messages ##########

Template.messages.rendered = ->
  if Session.equals 'channel', 'all'
    $('.message').hover ->
      $(".message").not("[data-channel='#{$(this).attr('data-channel')}']").addClass 'faded'
    , ->
      $('.message').removeClass 'faded'
  else
    ch = Channels.findOne
      name: Session.get('channel')
    nicks = (nick for nick of ch.nicks)
    $('#say-input').typeahead
      name: 'names'
      local: nicks

  if Session.equals 'scroll', false
    $(window).scrollTop($(document).height() - $(window).height())

Template.messages.events
  'keydown #say': (e, t) ->
  #'submit #say': (e, t) ->
    keyCode = e.keyCode or e.which
    if keyCode is 13
      e.preventDefault()
      message = t.find('#say-input').value
      $('#say-input').val('')
      Meteor.call 'say', Meteor.user(), Session.get('channel'), message

  'click, tap .load-next': ->
    handlers.messages[Session.get 'channel'].loadNextPage()

Template.messages.helpers
  all: ->
    Session.equals 'channel', 'all'
  messages: ->
    prev = null
    if Session.equals 'channel', 'all'
      messages = Messages.find({}, {sort: {time: 1}}).fetch()
    else
      messages = Messages.find(
        channel: Session.get 'channel'
      , sort: {time: 1}).fetch()

    #TODO: reduce code
    setPrev = (msg) ->
      msg.prev = prev
      prev = msg
    return (setPrev message for message in messages when message.from \
    not in Meteor.user().profile.channels[message.channel].ignore)

  notifications: ->
    Channels.findOne(name: Session.get 'channel')
    ?.notifications({sort: time: 1}) #FIXME: why do i need to check for existence.
  topic: ->
    unless Session.equals 'channel', 'all'
      Channels.findOne(name: Session.get 'channel')?.topic
  op_status: ->
    if Session.equals 'channel', 'all'
      return no
    else
      Channels.findOne(name: Session.get 'channel')?.nicks[Meteor.user().username] is '@'
  channel: ->
    Session.get 'channel'
  url_channel: ->
    Session.get('channel').match(/^(.)(.*)$/)[2]
  users: ->
    unless Session.equals 'channel', 'all'
      Channels.findOne(name: Session.get 'channel')?.users

Template.channel_header.helpers
  all: ->
    Session.equals 'channel', 'all'
  channel: ->
    Session.get 'channel'
  url_channel: ->
    Session.get('channel').match(/^(.)(.*)$/)[2]
  users: ->
    unless Session.equals 'channel', 'all'
      Channels.findOne(name: Session.get 'channel')?.users

########## Message ##########

Template.message.rendered = ->
  # Get message text.
  p = $(@find('p'))
  ptext = p.html()
  #TODO: combine all markdownification into a helper method.
  # Linkify URLs.
  ptext = ptext.replace regex.url, "<a href='$1' target='_blank'>$1</a>"
  # Linkify nicks.
  for nick, status of Channels.findOne(name: @data.channel).nicks
    ptext = ptext.replace regex.nick(nick), "$1<a href=\"#\">$2</a>$3"
  # Markdownify other stuff.
  ptext = ptext.replace regex.code, '$2<code>$3</code>$4'
  ptext = ptext.replace regex.bold, '$2<strong>$3</strong>$4'
  ptext = ptext.replace regex.underline, '$2<span class="underline">$3</span>$4'
  p.html(ptext)

Template.message.events
  'click .reply-action': ->
    $('#say-input').val("@#{@from} ")
    $('#say-input').focus()

  'click .ignore-action': ->
    {channels} = Meteor.user().profile
    #TODO: avoid duplicates
    channels[@channel]?.ignore.push @from
    Meteor.users.update \
      Meteor.userId(), $set: {'profile.channels': channels}

  'click, tap': (e, t) ->
    if Session.equals 'channel', 'all'
      # Slide toggle all messages not belonging to clicked channel
      # and set session to the new channel.
      if $('.message').not("[data-channel='#{@channel}']").length > 0
        $('.message').not("[data-channel='#{@channel}']").slideToggle 400, =>
          Session.set 'channel', @channel
      else
        Session.set 'channel', @channel

  'click .convo': (e, t) ->
    convo = t.find('.message').getAttribute 'data-convo'
    # Slide toggle all messages not belonging to clicked channel
    # and set session to the new channel.
    #.not("[data-channel='#{@to}']") do this if in 'all'
    $('.message')
    .not("[data-nick='#{@from}']")
    .not("[data-nick='#{convo}']")
    .slideToggle 400

  'click .kick': (e, t) ->
    Meteor.call 'kick', Meteor.user(), @channel, @from

Template.message.helpers
  joinToPrev: ->
    unless @prev is null
      @prev.from is @from and @prev.channel is @channel and @type() isnt 'mention' and @prev.type() isnt 'mention'
  all: ->
    Session.equals 'channel', 'all'
  convo: ->
    @convo()
  isConvo: ->
    if @convo() then yes else no
  timeAgo: ->
    moment(@time).fromNow()
  message_class: ->
    if @online() then @type() else "offline #{@type()}"
  op_status: ->
    Channels.findOne(name: @channel).nicks[Meteor.user().username] is '@'
  self: ->
    @type() is 'self'
  status: ->
    statuses =
      '@': 'operator'
      '%': 'half-operator'
      '+': 'voiced'
      '': 'normal'
    statuses[Channels.findOne(name: @channel).nicks[@from]]

Template.notification.timeAgo = ->
  moment(@time).fromNow()

Template.notification.events
  'click, tap li': ->
    $(window).scrollTop $("##{@_id}").offset().top - 10

  'click .close': ->
    # Do something

########## Explore ##########

Template.explore.events
  'click ul>li>h3>a': (e,t) ->
    name = e.toElement.outerText
    Meteor.call 'join', Meteor.user(), name
    ##TODO: combine with identicle lines below?
    Session.set 'channel', name
    $('#say-input').focus()

Template.explore.helpers
  channels: ->
    Channels.find {}, {sort : {users : -1}}

########## Settings ##########

Template.settings.events
  'submit #ignore-form': (e,t) ->
    e.preventDefault()
    ignoree = t.find('#inputIgnore').value
    t.find('#inputIgnore').value = ''
    console.log ignoree
    {channels} = Meteor.user().profile
    #TODO: avoid duplicates
    channels[Session.get('channel')]?.ignore.push ignoree
    Meteor.users.update \
      Meteor.userId(), $set: {'profile.channels': channels}

  'click .close': (e,t) ->
    {channels} = Meteor.user().profile
    #channels[Session.get('channel')]?.ignore.push ignoree
    index = channels[Session.get('channel')]?.ignore.indexOf(@)
    channels[Session.get('channel')]?.ignore.splice(index, 1)
    Meteor.users.update \
      Meteor.userId(), $set: {'profile.channels': channels}

  'click #privateCheckbox': (e,t) ->
    channel = Channels.findOne {name: Session.get('channel')}
    if 's' in channel.modes or 'i' in channel.modes
      Meteor.call 'modes', Meteor.user(), '-si'

Template.settings.helpers
  op_status: ->
    if Session.equals 'channel', 'all'
      return no
    else
      Channels.findOne(name: Session.get 'channel')?.nicks[Meteor.user().username] is '@'
  ignore_list: ->
    Meteor.user().profile.channels[Session.get('channel')]?.ignore

  private_checked: ->
    channel = Channels.findOne {name: Session.get('channel')}
    if 's' in channel.modes or 'i' in channel.modes
      return 'checked'
    else
      return ''


Meteor.Router.add
  '/': ->
    Session.set 'channel', 'all'
    return 'channel_main'

  '/explore': 'explore'

  '/logout': ->
    Meteor.logout -> Meteor.Router.to('/')

  '/channels/:channel/settings': (channel) ->
    Session.set 'channel', "##{channel}"
    return 'channel_settings'

  '/channels/:channel': (channel) ->
    Session.set 'channel', "##{channel}"
    return 'channel_main'

  '*': 'not_found'
