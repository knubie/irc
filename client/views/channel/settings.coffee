Template.settings.helpers
  op_status: ->
    console.log @
    @channel.nicks[Meteor.user().username] is '@'
  ignore_list: ->
    Meteor.user().profile.channels[@channel.name]?.ignore
  private_checked: ->
    if 's' in @channel.modes or 'i' in @channel.modes then 'checked' else ''
  readonly_checked: ->
    if 'm' in @channel.modes then 'checked' else ''

Template.settings.events
  'submit #topic-form-settings': (e,t) ->
    e.preventDefault()
    topic = t.find('#topic-name-settings').value
    Meteor.call 'topic', Meteor.user(), @channel._id, topic

  'submit #ignore-form-settings': (e,t) ->
    e.preventDefault()

    update Meteor.users, Meteor.userId()
    , "profile.channels.#{@channel.name}.ignore"
    , (ignore) ->
      ignore.push t.find('#ignore-username-settings').value
      _.uniq ignore

    # Clear input field
    t.find('#ignore-username-settings').value = ''

  'click .close': (e,t) ->
    update Meteor.users, Meteor.userId()
    , "profile.channels.#{Session.get('channel').name}.ignore"
    , (ignore) => _.reject ignore, (nick) => nick is "#{@}"

  'click label.checkbox[for="privateCheckbox"]': (e,t) ->
    if 's' in @channel.modes or 'i' in @channel.modes
      Meteor.call 'mode', Meteor.user(), @channel.name, '-si'
    else
      Meteor.call 'mode', Meteor.user(), @channel.name, '+si'

  'click label.checkbox[for="readonlyCheckbox"]': (e,t) ->
    if 'm' in @channel.modes
      Meteor.call 'mode', Meteor.user(), @channel.name, '-m'
    else
      Meteor.call 'mode', Meteor.user(), @channel.name, '+m'
