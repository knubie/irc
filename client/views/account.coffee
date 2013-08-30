# Set up flat checkboxes
Template.account.rendered = ->
  $('[data-toggle="checkbox"]').each ->
    $checkbox = $(this)
    $checkbox.checkbox()

# Preserver flat checkboxes
Template.account.preserve [
  '.checkbox'
  '#playSounds'
  '#sendNotifications'
  '.icons'
]

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

Template.account.events
  'click label.checkbox[for="playSounds"]': (e,t) ->
    Meteor.users.update(Meteor.userId(), $set: 'profile.sounds': not Meteor.user().profile.sounds)

Template.account.events
  'click label.checkbox[for="sendNotifications"]': (e,t) ->
    Meteor.users.update(Meteor.userId(), $set: 'profile.notifications': not Meteor.user().profile.notifications)
