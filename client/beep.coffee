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
  if message.channel?
    message.from not in Meteor.user().profile.channels[message.channel].ignore
  else
    true

# isMentioned :: Messages -> Boolean
isMentioned = (message) ->
  notIgnored(message) \
  # Username appears in message text.
  and regex.nick(Meteor.user().username).test(message.text)

# isPM :: Messages -> Boolean
isPM = (message) ->
  not message.channel?

# shouldSendNotification :: Message -> NotificationParams
shouldSendNotification = (message) ->
  if Meteor.user().profile.notifications and
  message.from isnt Meteor.user().username and
  (isPM(message) or isMentioned(message)) and
  (!document.hasFocus() or !Session.equals('channel', message.channel))
    return {
      image: ''
      title: "#{message.from} (#{if message.channel? then message.channel else 'Private message'})"
      text: message.text
    }

# createNotification :: NotificationParams -> Notification
sendNotification = (params) ->
  if params
    new Notification params.title,
      body: params.text

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
    if handlers.messages[Session.get('channel')]?.ready()
      beepAndNotify(id, message)
      if !document.hasFocus()
        unread += 1
        window.document.title = "(#{unread}) Jupe"
      unless Session.equals 'channel', message.channel
        channelUnread = Session.get("#{message.channel}.unread") or 0
        Session.set("#{message.channel}.unread", channelUnread + 1)
