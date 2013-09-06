# Set up flat checkboxes
Template.settings.rendered = ->
  $('[data-toggle="checkbox"]').each ->
    $checkbox = $(this)
    $checkbox.checkbox()

# Preserver flat checkboxes
Template.settings.preserve [
  '.checkbox'
  '#privateCheckbox'
  '#showHideJoins'
  '.icons'
]

Template.settings.events
  'submit #ignore-form': (e,t) ->
    e.preventDefault()
    ignoree = t.find('#inputIgnore').value
    t.find('#inputIgnore').value = ''
    {channels} = Meteor.user().profile
    channels[@name]?.ignore.push ignoree
    channels[@name]?.ignore = _.uniq channels[@name]?.ignore
    Meteor.users.update Meteor.userId()
    , $set: 'profile.channels': channels

  'click label.checkbox[for="privateCheckbox"]': (e,t) ->
    if 's' in @modes or 'i' in @modes
      Meteor.call 'mode', Meteor.user(), @name, '-si'
    else
      Meteor.call 'mode', Meteor.user(), @name, '+si'

  'click label.checkbox[for="showHideJoins"]': (e,t) ->
    console.log 'cliked joinpart'

Template.settings.helpers
  op_status: ->
    @nicks[Meteor.user().username] is '@'
  ignore_list: ->
    Meteor.user().profile.channels[@name]?.ignore
  private_checked: ->
    if 's' in @modes or 'i' in @modes then 'checked' else ''

