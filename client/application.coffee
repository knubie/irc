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
handlers.messages = Meteor.subscribeWithPagination 'messages', ->
  Session.get('channel.name')
, 30

Messages.find().observeChanges
  added: (id, doc) ->
    unless doc.read
      if doc.convo is Meteor.user().username and \
      doc.from not in Meteor.user().profile.channels[doc.channel].ignore
        notifications[id] ?= new Notification doc.channel, doc.text
        notifications[id].showOnce()


########## Startup ##########

Meteor.startup ->
  # Store scroll position in a session variable. This keeps the scroll
  # position in place when receiving new messages, unless the user is
  # scrolled to the bottom, then it forces the scroll position to the
  # bottom even when new messages get rendered.
  $(window).scroll ->
    Session.set 'scroll', \
      $(document).height() - ($(window).scrollTop() + $(window).height())
      #handlers.messages.reset()

    # If close to top and messages handler is ready.
    if $(window).scrollTop() <= 95 and handlers.messages.ready()
      # Load messages subscription next page.
      handlers.messages.loadNextPage()

