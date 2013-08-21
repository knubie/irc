########## Notifications ##########
notifications = {}
class Notification
  constructor: (title, message) ->
    if window.webkitNotifications.checkPermission() is 0
      @self = window.webkitNotifications.createNotification 'icon.png', title, message
      @count = 0
  show: ->
    @self.show()
    @count++
  showOnce: ->
    if @count < 1
      @self.show()

########## Defaults ##########

# Currently selected channel for viewing messages.
Session.setDefault 'channel.name', 'all'
Session.setDefault 'channel.id', null
# Push messages to the bottom by default (ie don't save scroll position).
Session.setDefault 'scroll', 0
#Session.setDefault 'position from bottom', 0

########## Subscriptions ##########

@handlers = {messages:{},channel:{}}
handlers.user = Meteor.subscribe 'users'
handlers.channel = Meteor.subscribe 'channels'
# Get channel for users not logged in.
handlers.messages[Session.get('channel.name')] = Meteor.subscribeWithPagination 'messages', Session.get('channel.name'), 30
# Wait 200ms for Meteor.user() to show up
Meteor.setTimeout -> #FIXME: this is shameful
  for channel of Meteor.user().profile.channels
    console.log channel
    handlers.messages[channel] = Meteor.subscribeWithPagination 'messages', channel, 30
, 200

#handlers.messages = Meteor.subscribeWithPagination 'messages', ->
  #Session.get('channel.name')
#, 30

Messages.find().observeChanges
  added: (id, doc) ->
    unless doc.read
      if doc.convo is Meteor.user().username and \
      doc.from not in Meteor.user().profile.channels[doc.channel].ignore
        notifications[id] ?= new Notification doc.channel, doc.text
        notifications[id].showOnce()


########## Startup ##########

Meteor.startup ->
  channelHeaderTop = 0
  # Store scroll position in a session variable. This keeps the scroll
  # position in place when receiving new messages, unless the user is
  # scrolled to the bottom, then it forces the scroll position to the
  # bottom even when new messages get rendered.
  updateStuff = ->
    currScroll = $(document).height() - ($(window).scrollTop() + $(window).height())

    if currScroll > Session.get('scroll') and currScroll > 0 and channelHeaderTop < 0
      channelHeaderTop = channelHeaderTop - (Session.get('scroll') - currScroll)
      channelHeaderTop = 0 if channelHeaderTop > 0
      $('.channel-header').css('-webkit-transform', "translate(0,#{channelHeaderTop}px)")
    else if currScroll < Session.get('scroll') and currScroll > 0 and channelHeaderTop > -76
      channelHeaderTop = channelHeaderTop - (Session.get('scroll') - currScroll)
      channelHeaderTop = -76 if channelHeaderTop < -76
      $('.channel-header').css('-webkit-transform', "translate(0,#{channelHeaderTop}px)")

    Session.set 'scroll', \
      $(document).height() - ($(window).scrollTop() + $(window).height())
      #handlers.messages.reset()

    # If close to top and messages handler is ready.
    if $(window).scrollTop() <= 95 and handlers.messages[Session.get('channel.name')].ready()
      # Load messages subscription next page.
      Log.info 'load next'
      handlers.messages[Session.get('channel.name')].loadNextPage()

  if Modernizr.touch
    $(window).on 'touchmove', (e) ->
      touches = e.originalEvent.changedTouches
      updateStuff()
  else
    $(window).scroll updateStuff
