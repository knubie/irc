########## Defaults ##########

Session.setDefault 'channel.name', 'all' #Current channel.
Session.setDefault 'channel.id', null # Current channel id
Session.setDefault 'scroll', 0 # Scroll position
Session.setDefault 'messages.page', 1 # Messages handler pagination
Session.setDefault 'messages.rendered', false
Session.setDefault 'joinAfterLogin', null


onNewMessage = (msg) ->
  console.log 'new msg'
  if Meteor.user().profile.sounds
    console.log 'beep'
    # Play beep sound
    $('#beep')[0].play()

  if Meteor.user().profile.notifications
    if regex.nick(Meteor.user().username).test(msg.text) \
    and msg.from not in Meteor.user().profile.channels[msg.channel].ignore
      window.webkitNotifications.createNotification('icon.png'
      , "#{msg.from} (#{msg.channel})"
      , msg.text)
      .show()

    if not msg.channel.isChannel() # Private message
      window.webkitNotifications.createNotification('icon.png'
      , "#{msg.from} (#{msg.channel})"
      , msg.text)
      .show()

########## Subscriptions ##########

@handlers =
  user: Meteor.subscribe 'users'
  channel: Meteor.subscribe 'channels'
  messages: {}
  mentions: {}
Deps.autorun ->
  limit = (PERPAGE * Session.get('messages.page')) + PERPAGE
  handlers.messages.all = Meteor.subscribe 'messages', 'all', limit,
    onReady: ->
      console.log "all onReady"
  #for channel of Meteor.user()?.profile.channels
  _.map Meteor.user()?.profile.channels, (value, channel, list) ->
    unless handlers.messages[channel]?.ready()
      console.log "set handler for #{channel}"
      handlers.messages[channel]?.stop()
      handlers.messages[channel] = Meteor.subscribe 'messages', channel, limit,
        onReady: ->
          Messages.find({channel}).observeChanges
            added: (id, msg) =>
              if @ready
                onNewMessage(msg)

    #handlers.mentions[channel] = Meteor.subscribe 'mentions', channel, limit


########## Startup ##########

Meteor.startup ->
  # Set up FastClick for more responsive touch events.
  FastClick.attach(document.body)

  # Store scroll position in a session variable. This keeps the scroll
  # position in place when receiving new messages, unless the user is
  # scrolled to the bottom, then it forces the scroll position to the
  # bottom even when new messages get rendered.
  @rememberScrollPosition = ->
    $doc = $(document)
    $win = $(window)
    if ($(document).height() - ($(window).scrollTop() + $(window).height())) > $(document).height()
      Session.set 'scroll', $(document).height()
    else
      Session.set 'scroll', \
        $(document).height() - ($(window).scrollTop() + $(window).height())

  @scrollToPlace = ->
    $(window).scrollTop \
      $(document).height() - $(window).height() - Session.get('scroll')

  @isElementInViewport = (el) ->
    rect = el.getBoundingClientRect()
    rect.top >= 160 && rect.left >= 0 && rect.bottom <= $(window).height()

