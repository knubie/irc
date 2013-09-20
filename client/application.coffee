########## Defaults ##########

Session.setDefault 'channel.name', 'all' #Current channel.
Session.setDefault 'channel.id', null # Current channel id
Session.setDefault 'scroll', 0 # Scroll position
Session.setDefault 'messages.page', 1 # Messages handler pagination
Session.setDefault 'messages.rendered', false


########## Subscriptions ##########

@handlers =
  user: Meteor.subscribe 'users'
  channel: Meteor.subscribe 'channels'
  messages: {}
  mentions: {}
Deps.autorun ->
  limit = (PERPAGE * Session.get('messages.page')) + PERPAGE
  handlers.messages.all = Meteor.subscribe 'messages', 'all', limit
  for channel of Meteor.user()?.profile.channels
    handlers.messages[channel] = Meteor.subscribe 'messages', channel, limit
    handlers.mentions[channel] = Meteor.subscribe 'mentions', channel, limit


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

    # If close to top and messages handler is ready.
    #if $(window).scrollTop() <= 150 and handlers.messages[Session.get('channel.name')].ready() and Session.equals 'messages.rendered', true
      ## Load messages subscription next page.
      #Log.info 'load next'
      #Log.info Session.get('messages.page')
      #Session.set 'messages.page', Session.get('messages.page') + 1
      #Session.set('messages.rendered', false)
    #if Session.get('scroll') < 1 and Session.get('messages.page') > 1
      #Session.set 'messages.page', 1

  # Images loaded hook
  @onImagesLoad = (callbacks) ->
    images = 0
    $("img").each (key) ->
      item = $(this)
      img = new Image()
      images++
      img.onload = ->
        images--
        callbacks.each?()
      img.src = item.attr("src")
    check = setInterval ->
      if images is 0
        callbacks.final?()
        clearInterval(check)
    , 50
  @scrollToPlace = ->
    $(window).scrollTop \
      $(document).height() - $(window).height() - Session.get('scroll')

  @isElementInViewport = (el) ->
    rect = el.getBoundingClientRect()
    rect.top >= 160 && rect.left >= 0 && rect.bottom <= $(window).height()

