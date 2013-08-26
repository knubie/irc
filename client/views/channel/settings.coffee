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

  'click #privateCheckbox': (e,t) ->
    channel = Channels.findOne Session.get('channel.id')
    if 's' in channel.modes or 'i' in channel.modes
      Meteor.call 'mode', Meteor.user(), Session.get('channel.name'), '-si'
    else
      Meteor.call 'mode', Meteor.user(), Session.get('channel.name'), '+si'

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

