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
    new Notification params.title,
      body: params.text
    #window.webkitNotifications.createNotification(params.image, params.title, params.text).show()

# dispatchNotification :: Message -> Action(UI)
dispatchNotification = _.compose sendNotification, shouldSendNotification

beepAndNotify = (id, message) ->
  if handlers.messages?.ready()
    _.compose(dispatchNotification, beep) message

########## Beeps / Notifications ##########

unread = 0
$(window).focus ->
  window.document.title = "Jupe"
  unread = 0

Messages.find().observeChanges
  added: (id, message) ->
    beepAndNotify(id, message)
    if !document.hasFocus() and handlers.messages?.ready()
      unread += 1
      window.document.title = "(#{unread}) Jupe"
