########## Functions ##########

# beep :: Action(UI)
beep = (message) ->
  if Session.equals 'channel', message.channel \
  and Meteor.user().profile.sounds \
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

@beepAndNotify = (id, message) ->
  _.compose(dispatchNotification, beep) message

########## Beeps / Notifications ##########

init = true
unread = 0
$(window).focus ->
  unread = 0
  window.document.title = "Jupe"
Messages.find({}).observeChanges
  added: (id, message) =>
    unless init
      beepAndNotify(id, message)
      unless document.hasFocus()
        unread++
        window.document.title = "(#{unread}) Jupe"
      unless Session.equals 'channel', message.channel
        console.log 'unread'
        channelUnread = Session.get("#{message.channel}.unread") or 0
        Session.set("#{message.channel}.unread", channelUnread + 1)
init = false
