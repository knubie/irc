########## Defaults ##########

# Currently selected channel for viewing messages.
Session.setDefault 'channel', 'all'
# Push messages to the bottom by default (ie don't save scroll position).
Session.setDefault 'scroll', false

########## Subscriptions ##########

@handlers = {messages:{},channel:{}}
handlers.user = Meteor.subscribe 'users'
#handlers.messages = Meteor.subscribe 'messages'
handlers.channel = Meteor.subscribe 'channels', ->
  subscribeToMessagesOf = (channel) ->
    handlers.messages[channel.name] = Meteor.subscribeWithPagination 'messages'
    , channel.name
    , 30
    Messages.find().observeChanges
      added: (id, doc) ->
        unless doc.read
          if doc.convo is Meteor.user().username and \
          doc.from not in Meteor.user().profile.channels[doc.channel].ignore
            notifications[id] ?= new Notification doc.channel, doc.text
            notifications[id].showOnce()

  subscribeToMessagesOf channel for channel in Channels.find().fetch()
  Channels.find().observe
    added: subscribeToMessagesOf

########## Startup ##########
#
Meteor.startup ->
  # Store scroll position in a session variable. This keeps the scroll
  # position in place when receiving new messages, unless the user is
  # scrolled to the bottom, then it forces the scroll position to the
  # bottom even when new messages get rendered.
  $(window).scroll ->
    # If not scrolled to the bottom
    if $(window).scrollTop() < $(document).height() - $(window).height()
      Session.set 'scroll', true
    else
      Session.set 'scroll', false

    # If close to top and messages handler is ready.
    if $(window).scrollTop() <= 50 and handlers.messages[Session.get 'channel.name'].ready()
      # Load messages subscription next page.
      handlers.messages[Session.get 'channel.name'].loadNextPage()
