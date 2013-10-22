########## Functions ##########

# beep :: Action(UI)
beep = (message) ->
  # Check if sounds are enabled in the user profile.
  if Meteor.user().profile.sounds \
  and notIgnored(message) \
  and message.from isnt Meteor.user().username
    $('#beep')[0].play() # Play beep sound
  return message

# notIgnored :: Messages -> Boolean
notIgnored = (message) ->
  # Not in ignore-list
  message.from not in Meteor.user().profile.channels[message.channel].ignore

# isMentioned :: Messages -> Boolean
isMentioned = (message) ->
  notIgnored(message) \
  # Username appears in message text.
  and regex.nick(Meteor.user().username).test(message.text)

# notIgnored :: Messages -> Boolean
isPM = (message) ->
  not message.channel.isChannel()

# shouldSendNotification :: Message -> NotificationParams
shouldSendNotification = (message) ->
  if Meteor.user().profile.notifications \
  and message.from isnt Meteor.user().username \
  and (isMentioned(message) or isPM(message))
    return {
      image: 'icon.png'
      title: "#{message.from} (#{message.channel})"
      text: message.text
    }

# createNotification :: NotificationParams -> Notification
sendNotification = (params) ->
  if params
    window.webkitNotifications.createNotification(params.image, params.title, params.text)
    .show()

# dispatchNotification :: Message -> Action(UI)
dispatchNotification = _.compose sendNotification, shouldSendNotification

beepAndNotify = (id, message) ->
  if handlers.messages[message.channel]?.ready()
    _.compose(dispatchNotification, beep) message

########## Defaults ##########

Session.setDefault 'channel.name', 'all' #Current channel.
Session.setDefault 'channel.id', null # Current channel id
Session.setDefault 'scroll', 0 # Scroll position
Session.setDefault 'messages.page', 1 # Messages handler pagination
Session.setDefault 'messages.rendered', false
Session.setDefault 'joinAfterLogin', null # Which channel to join after signing up or logging in.

########## Subscriptions ##########

@handlers =
  user: Meteor.subscribe 'users'
  publicChannels: Meteor.subscribe 'publicChannels'
  messages: new Object
  mentions: new Object

Deps.autorun ->
  limit = (PERPAGE * Session.get('messages.page'))
  handlers.messages.all = Meteor.subscribe 'messages', 'all', limit
  for channel of Meteor.user()?.profile.channels
  #_.map Meteor.user()?.profile.channels, (value, channel, list) ->
    handlers.messages[channel] = Meteor.subscribe 'messages', channel, limit
    handlers.mentions[channel] = Meteor.subscribe 'mentions', channel, limit
  if Meteor.user()
    handlers.joinedChannels = Meteor.subscribe 'joinedChannels'

########## Beeps / Notifications ##########

Messages.find().observeChanges
  added: beepAndNotify

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

