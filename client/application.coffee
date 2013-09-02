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
Session.setDefault 'messages.page', 1

########## Subscriptions ##########

@handlers = {messages:{},channel:{}}
handlers.user = Meteor.subscribe 'users'
handlers.channel = Meteor.subscribe 'channels'
Deps.autorun ->
  limit = 30 * Session.get('messages.page')
  handlers.messages.all = Meteor.subscribe 'messages', 'all', limit
  if Meteor.user()
    for channel of Meteor.user().profile.channels
      handlers.messages[channel] = Meteor.subscribe 'messages', channel, limit

Messages.find().observeChanges
  added: (id, doc) ->
    unless doc.read
      if Meteor.user().profile.sounds
        document.getElementById('beep').play()
      if doc.convo is Meteor.user().username and \
      doc.from not in Meteor.user().profile.channels[doc.channel].ignore
        if Meteor.user().profile.notifications
          notifications[id] ?= new Notification "#{doc.from} (#{doc.channel})", doc.text
          notifications[id].showOnce()


########## Startup ##########

Meteor.startup ->
  FastClick.attach(document.body)
  # Store scroll position in a session variable. This keeps the scroll
  # position in place when receiving new messages, unless the user is
  # scrolled to the bottom, then it forces the scroll position to the
  # bottom even when new messages get rendered.
  @updateStuff = ->
    #unless Modernizr.touch
    if false
      $channelHeader = $('.channel-header')
      currScroll = $(document).height() - ($(window).scrollTop() + $(window).height())

      if currScroll > Session.get('scroll') \ # Scrolling up
      and currScroll > 0 \ # Not 'bouncing' past the bottom
      and $channelHeader.height() < 78 # At least partially hidden

        $channelHeader.height(
          $channelHeader.height() - (Session.get('scroll') - currScroll)
        )
        if $channelHeader.height() > 78
          $channelHeader.height(78)

      else if currScroll < Session.get('scroll') \ # Scrolling down
      and currScroll > 0 \ # Not 'bouncing' past the bottom
      and $channelHeader.height() > 26 # Not totally hidden yet

        $channelHeader.height(
          $channelHeader.height() - (Session.get('scroll') - currScroll)
        )
        if $channelHeader.height() < 26
          $channelHeader.height(26)

    Session.set 'scroll', \
      $(document).height() - ($(window).scrollTop() + $(window).height())
      #handlers.messages.reset()

    # If close to top and messages handler is ready.
    if $(window).scrollTop() <= 150 and handlers.messages[Session.get('channel.name')].ready()
      # Load messages subscription next page.
      Log.info 'load next'
      Session.set 'messages.page', Session.get('messages.page') + 1
      handlers.messages[Session.get('channel.name')] = Meteor.subscribe 'messages'
      , Session.get('channel.name')
      , Session.get('messages.page') * 30
      #handlers.messages[Session.get('channel.name')].loadNextPage()
    if Session.get('scroll') < 1 and Session.get('messages.page') > 1
      Log.info 'reset handler'
      Session.set 'messages.page', 1
      handlers.messages[Session.get('channel.name')] = Meteor.subscribe 'messages'
      , Session.get('channel.name')
      , Session.get('messages.page') * 30

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
