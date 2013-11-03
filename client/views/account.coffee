Template.account.data = -> Meteor.user()

Template.account.helpers
  soundsChecked: ->
    if @profile.sounds
      return 'checked'
    else
      return ''

  notificationsChecked: ->
    if @profile.notifications
      return 'checked'
    else
      return ''

  realNameValue: ->
    @profile.realName or ''

Template.account.events
  'submit #real-name-settings': (e,t) ->
    console.log 'real name submission.'
    e.preventDefault()
    if Meteor.user().profile.realName?
      if (realNameValue = t.find('#realNameForm').value) isnt Meteor.user().profile.realName
        Meteor.users.update(Meteor.userId(), $set: 'profile.realName': realNameValue)
    else
      console.log 'no real name'
      realNameValue = t.find('#realNameForm').value
      Meteor.users.update(Meteor.userId(), $set: 'profile.realName': realNameValue)

  'click label.checkbox[for="playSounds"]': (e,t) ->
    Meteor.users.update Meteor.userId(),
      $set: 'profile.sounds': not Meteor.user().profile.sounds

  'click label.checkbox[for="sendNotifications"]': (e,t) ->
    if window.webkitNotifications.checkPermission() is 1 and not Meteor.user().profile.notifications
      webkitNotifications.requestPermission()
    Meteor.users.update(Meteor.userId(), $set: 'profile.notifications': not Meteor.user().profile.notifications)
