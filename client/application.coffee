########## Defaults ##########

Session.setDefault 'channel.name', 'all' #Current channel.
Session.setDefault 'channel.id', null # Current channel id
Session.setDefault 'scroll', 0 # Scroll position
Session.setDefault 'messages.page', 1 # Messages handler pagination
Session.setDefault 'messages.rendered', false
Session.setDefault 'joinAfterLogin', null # Which channel to join after signing up or logging in.
Session.setDefault 'channel', null
Session.setDefault 'pm', null


########## Subscriptions ##########

@handlers =
  user: Meteor.subscribe 'users'
  publicChannels: Meteor.subscribe 'publicChannels'
  messages: new Object
  mentions: new Object

Deps.autorun ->
  limit = (PERPAGE * Session.get('messages.page'))
  if Meteor.user()?
    channels = (channel for channel of Meteor.user().profile.channels)
    handlers.messages.all = Meteor.subscribe 'messages', channels, limit
  for user of Meteor.user()?.profile.pms
    handlers.messages[user] = Meteor.subscribe 'privateMessages', user, limit
  if Session.equals('subPage', 'mentions')
    channel = Session.get('channel').name
    handlers.mentions[channel] = Meteor.subscribe 'mentions', channel, limit
  if Meteor.user()
    handlers.joinedChannels = Meteor.subscribe 'joinedChannels'

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
    Session.set 'scroll', $(document).height() - $(window).scrollTop() + $(window).height()

@scrollToPlace = ->
  if Session.equals 'scroll', 0
  #if ($(window).scrollTop() + $(window).height()) >= $(document).height()
    $(window).scrollTop $(document).height()
  #$(window).scrollTop \
    #$(document).height() - $(window).height() - Session.get('scroll')
    #
@stayInPlace = ->
  $(window).scrollTop $(document).height() - Session.get('scroll') - $(window).height()


@isElementInViewport = (el) ->
  rect = el.getBoundingClientRect()
  rect.top >= 160 && rect.left >= 0 && rect.bottom <= $(window).height()

