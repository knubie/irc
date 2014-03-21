########## Defaults ##########

Session.setDefault 'channel.id', null # Current channel id
Session.setDefault 'scroll', 0 # Scroll position
Session.setDefault 'messages.page', 1 # Messages handler pagination
Session.setDefault 'channel', null
Session.setDefault 'pm', null
Session.setDefault 'joinAfterLogin', null # Channel to join after signup/login
Session.setDefault 'message length', 0
Session.setDefault 'last message', ''

########## Dependenies ##########

@timeAgoDep = new Deps.Dependency # Rerendering message timestamp
@userListDep = new Deps.Dependency # Show/hide user list

########## Subscriptions ##########

@handlers =
  user: Meteor.subscribe 'users'
  publicChannels: Meteor.subscribe 'publicChannels'

Deps.autorun ->
  if Meteor.user()?
    # Subscribe to all messages feed.
    channels = (channel for channel of Meteor.user().profile.channels)
    handlers.allMessages = Meteor.subscribe 'messages', channels, PERPAGE

    # Subscribed to joined channels (including private channels)
    handlers.joinedChannels = Meteor.subscribe 'joinedChannels'

########## Startup ##########

Meteor.startup ->
  # Set up FastClick for more responsive touch events.
  FastClick.attach(document.body)

  # When window loses focus, incoming message causes title to change.
  $(window).on 'focus', -> window.document.title = "Jupe"

# Store scroll position in a session variable. This keeps the scroll
# position in place when receiving new messages, unless the user is
# scrolled to the bottom, then it forces the scroll position to the
# bottom even when new messages get rendered.
@rememberScrollPosition = ->
  $doc = $(document)
  $win = $(window)
  # if scrolltop + window.height >= document.height
  # window.scrolltop(document.height)
  #if ($(document).height() - ($(window).scrollTop() + $(window).height())) > $(document).height()
    #Session.set 'scroll', $(document).height()
  #else
    #Session.set 'scroll', \
      #$(document).height() - ($(window).scrollTop() + $(window).height())

  if ($(window).scrollTop() + $(window).height()) >= $(document).height()
    Session.set 'scroll', 0
  else
    Session.set 'scroll', $(document).height() - ($(window).scrollTop() + $(window).height())

@scrollToPlace = ->
  if Session.equals 'scroll', 0
    $(window).scrollTop $(document).height()
    $('.messages').scrollTop $('.messages')[0].scrollHeight
  else
    if not Session.equals('message length', $('.message').length)
      Session.set 'message length', $('.message').length
      # From top
      if Session.equals('last message', $('.message').last().attr('id'))
        # Stay in place
        $(window).scrollTop($(document).height() - $(window).height() - Session.get('scroll'))
      # From bottom
      else
        # Do nothing
        Session.set 'last message', $('.message').last().attr('id') 


@stayInPlace = ->
  $(window).scrollTop $(document).height() - Session.get('scroll') - $(window).height()


@isElementInViewport = (el) ->
  rect = el.getBoundingClientRect()
  rect.top >= 160 && rect.left >= 0 && rect.bottom <= $(window).height()
