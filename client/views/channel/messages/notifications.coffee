########## Notifications ##########
class Notification
  constructor: (title, message) ->
    if window.webkitNotifications.checkPermission() is 0
      @self = window.webkitNotifications.createNotification 'icon.png', title, message
      @count = 0
  show: ->
    @self.show()
    @count++
    console.log 'show'
  showOnce: ->
    console.log 'show once'
    if @count < 1
      @self.show()

########## Dispatch ##########
Messages.find().observeChanges
  added: (id, msg) ->
    unless msg.read
      # Beep on new message
      $('#beep')[0].play() if Meteor.user().profile.sounds

      if Meteor.user().profile.notifications
        if msg.convo is Meteor.user().username \ # Mentioned
        and msg.from not in Meteor.user().profile.channels[msg.channel].ignore
          new Notification("#{msg.from} (#{msg.channel})", msg.text).showOnce()

        if not msg.channel.isChannel() # Private message
          new Notification("#{msg.from}", msg.text).showOnce()

