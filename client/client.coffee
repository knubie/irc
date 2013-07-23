########## Defaults ##########

# Currently selected channel for viewing messages.
Session.setDefault 'channel', 'all'
# Push messages to the bottom by default (ie don't save scroll position).
Session.setDefault 'scroll', false

########## Subscriptions ##########
handlers = {messages:{},channel:{}}
handlers.user = Meteor.subscribe 'users'
handlers.channel = Meteor.subscribe 'channels', ->
  subscribeToMessagesOf = (channel) ->
    handlers.messages[channel.name] = Meteor.subscribeWithPagination 'messages'
    , channel.name
    , 30
  subscribeToMessagesOf channel for channel in Channels.find().fetch()
  Channels.find().observe
    added: subscribeToMessagesOf

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
    Meteor.call 'remember', username, password, email

  'submit #form-signin': (e,t) ->
    e.preventDefault()
    username = t.find('#signin-username').value
    password = t.find('#signin-password').value
    Meteor.loginWithPassword username, password

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
  connecting: ->
    Meteor.user().profile.connecting

########## Channels ##########

Template.channels.events
  'submit #new-channel': (e, t) ->
    e.preventDefault()
    name = t.find('#new-channel-name').value
    t.find('#new-channel-name').value = ''
    Channels.insert {owner: Meteor.userId(), name}
    Meteor.call 'join', Meteor.user(), name
    #TODO: combine with identicle lines below?
    Session.set 'channel', name
    $('#say-input').focus()

  'click, tap .channel': (e,t) ->
    Session.set 'channel', @name
    $('#say-input').focus()

  'click .close': ->
    Meteor.call 'part', Meteor.user(), @name
    Session.set 'channel', 'all'

Template.channels.helpers
  channels: ->
    Channels.find owner: Meteor.userId()
  selected: ->
    if Session.equals 'channel', @name then 'selected' else ''
  notification_count: ->
    if @notifications().length < 1 then '' else @notifications().length

########## Messages ##########

Template.messages.rendered = ->
  if Session.equals 'channel', 'all'
    $('.message').hover ->
      $(".message").not("[data-channel='#{$(this).attr('data-channel')}']").addClass 'faded'
    , ->
      $('.message').removeClass 'faded'
  if Session.equals 'scroll', false
    $(window).scrollTop($(document).height() - $(window).height())

  #ch = Channels.findOne
    #owner: Meteor.userId()
    #name: Session.get('channel')
  #FIXME: this breaks the messages.events
  #$('#say-input').typeahead
    #name: 'names'
    #local: [
      #'? Type @ to mention nicks.'
      #'? Click on \'View conversation\' to isolate a conversation between two users.'
      #'? Hover over message in \'all\' view to messages from the same channel.'
      #'? Click any message in \'all\' view to jump to that channel.'
      #'? Basic formatting: *bold*, _underline_, and `inline code`.'
      #'@matty'
      #'@oddmunds'
      #'@entel'
      #'@weezy'
      #'@costanza'
    #]
    #local: ch.nicks

Template.messages.events
  'submit #say': (e, t) ->
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
    Channels.findOne(owner: Meteor.userId(), name: Session.get 'channel')
    ?.messages({sort: time: 1}) #FIXME: why do i need to check for existence.
    ?.map (msg) ->
      msg.prev = prev
      prev = msg
  notifications: ->
    Channels.findOne(owner: Meteor.userId(), name: Session.get 'channel')
    ?.notifications({sort: time: 1}) #FIXME: why do i need to check for existence.

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
  'click .reply': ->
    $('#say-input').val("#{@from} ")
    $('#say-input').focus()

  'click, tap': (e, t) ->
    if Session.equals 'channel', 'all'
      # Slide toggle all messages not belonging to clicked channel
      # and set session to the new channel.
      $('.message').not("[data-channel='#{@channel}']").slideToggle 400, =>
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
    Channels.findOne(name: Session.get 'channel' ).status() is '@'
  self: ->
    @type() is 'self'
  status: ->
    statuses =
      '@': 'operator'
      '%': 'half-operator'
      '+': 'voiced'
      '': 'normal'
    statuses[Channels.findOne(name: Session.get 'channel').nicks[@from]]

Template.notification.timeAgo = ->
  moment(@time).fromNow()

Template.notification.events
  'click, tap li': ->
    $(window).scrollTop $("##{@_id}").offset().top - 10

  'click .close': ->
    Messages.update
      _id: @_id
    , {$set: {'type': 'normal'}}

########## Message ##########

Template.explore.events
  'click ul>li>h3>a': (e,t) ->
    console.log t
    console.log e
    name = e.toElement.outerText
    Channels.insert {owner: Meteor.userId(), name}
    Meteor.call 'join', Meteor.user(), name
    ##TODO: combine with identicle lines below?
    Session.set 'channel', name
    $('#say-input').focus()

Template.explore.helpers
  channels: ->
    Channels.find {owner: 'network'}, {sort : {count : -1}}

Meteor.Router.add
  '/': 'messages'
  '/explore': 'explore'

  '*': 'not_found'
