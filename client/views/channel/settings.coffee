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

  'click .close': (e,t) ->
    {channels} = Meteor.user().profile
    index = channels[Session.get('channel.name')]?.ignore.indexOf(@)
    channels[Session.get('channel.name')]?.ignore.splice(index, 1)
    Meteor.users.update Meteor.userId()
    , $set: 'profile.channels': channels

  'click label.checkbox[for="privateCheckbox"]': (e,t) ->
  #'click #privateCheckbox': (e,t) ->
    console.log 'click dat thang'
    channel = Channels.findOne Session.get('channel.id')
    if 's' in channel.modes or 'i' in channel.modes
      Meteor.call 'mode', Meteor.user(), Session.get('channel.name'), '-si'
    else
      Meteor.call 'mode', Meteor.user(), Session.get('channel.name'), '+si'

  'click label.checkbox[for="showHideJoins"]': (e,t) ->
    console.log 'cliked joinpart'

Template.settings.helpers
  op_status: ->
    if Session.equals 'channel.name', 'all'
      return no
    else
      Channels.findOne(Session.get 'channel.id')?.nicks[Meteor.user().username] is '@'
  ignore_list: ->
    Meteor.user().profile.channels[Session.get('channel.name')]?.ignore
  private_checked: ->
    channel = Channels.findOne Session.get('channel.id')
    if 's' in channel.modes or 'i' in channel.modes
      return 'checked'
    else
      return ''

