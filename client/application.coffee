########## Defaults ##########

Session.setDefault 'channel.id', null # Current channel id
Session.setDefault 'scroll', 0 # Scroll position
Session.setDefault 'messages.page', 1 # Messages handler pagination
Session.setDefault 'channel', null
Session.setDefault 'pm', null
Session.setDefault 'joinAfterLogin', null # Channel to join after signup/login

########## Dependenies ##########

@timeAgoDep = new Deps.Dependency # Rerendering message timestamp
@userListDep = new Deps.Dependency # Show/hide user list

########## Subscriptions ##########

subs = new SubsManager
  # will be cached only 20 recently used subscriptions
  cacheLimit: 20,
  # any subscription will be expired after 5 minutes of inactivity
  expireIn: 5

@handlers =
  messages: {}
  _messages: (channel) ->
    #Meteor.subscribe 'messages', channel, \
    #PERPAGE * Session.get('messages.page')
    subs.subscribe 'messages', channel, \
    PERPAGE * Session.get('messages.page')
  joinedChannels: ->
    Meteor.subscribe 'joinedChannels'
  allMessages: ->
    Meteor.subscribe 'allMessages', Meteor.userId(), PERPAGE
  publicChannels: null
  user: Meteor.subscribe 'users'
  #publicChannels: Meteor.subscribe 'publicChannels'

@subscribeToChannelsAndMessages = ->
  # Subscribe to all message feeds.
  channels = (channel for channel of Meteor.user().profile.channels)
  for channel in channels
    handlers.messages[channel] = \
      # FIXME: have specific page variable for each channel
      Meteor.subscribe 'messages', channel, \
      PERPAGE * Session.get('messages.page')

  # Subscribe to all messages
  handlers.allMessages = Meteor.subscribe 'allMessages', Meteor.userId(), PERPAGE

  # Subscribe to joined channels (including private channels)
  handlers.joinedChannels = Meteor.subscribe 'joinedChannels'

########## Startup ##########

Meteor.startup ->
  # Set up FastClick for more responsive touch events.
  FastClick.attach(document.body)

  # When window loses focus, incoming message causes title to change.
  $(window).on 'focus', -> window.document.title = "Jupe"

  # Initialize tooltips
  $('body').tooltip
    selector: '[data-toggle=tooltip]'

# Store scroll position in a session variable. This keeps the scroll
# position in place when receiving new messages, unless the user is
# scrolled to the bottom, then it forces the scroll position to the
# bottom even when new messages get rendered.
@rememberScrollPosition = ->
  $doc = $(document)
  $win = $(window)

  if ($win.scrollTop() + $win.height()) >= $doc.height()
    Session.set 'scroll', 0
  else
    Session.set 'scroll', $doc.height() - ($win.scrollTop() + $win.height())

@scrollToPlace = ->
  if Session.equals 'scroll', 0
    $(window).scrollTop $(document).height()
    $('.messages').scrollTop $('.messages')[0].scrollHeight
  else
    # Stay in place
    $(window).scrollTop($(document).height() - $(window).height() - Session.get('scroll'))

@isElementInViewport = (el) ->
  rect = el.getBoundingClientRect()
  rect.top >= 160 && rect.left >= 0 && rect.bottom <= $(window).height()

########## Moment Config ##########
#moment.lang 'en',
  #relativeTime:
    #s: '%ds'
    #m: 'm'
    #mm: '%dm'
    #h: 'h'
    #hh: '%dh'
