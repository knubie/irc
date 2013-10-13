Template.settings.helpers
  op_status: ->
    @nicks[Meteor.user().username] is '@'
  ignore_list: ->
    Meteor.user().profile.channels[@name]?.ignore
  private_checked: ->
    if 's' in @modes or 'i' in @modes then 'checked' else ''

Template.settings.events
  'submit #ignore-form-settings': (e,t) ->
    e.preventDefault()

    update Meteor.users, Meteor.userId()
    , "profile.channels.#{@name}.ignore"
    , (ignore) ->
      ignore.push t.find('#ignore-username-settings').value
      _.uniq ignore

    # Clear input field
    t.find('#ignore-username-settings').value = ''

  'click .close': (e,t) ->

    update Meteor.users, Meteor.userId()
    , "profile.channels.#{Session.get('channel.name')}.ignore"
    , (ignore) => _.reject ignore, (nick) => nick is "#{@}"


  'click label.checkbox[for="privateCheckbox"]': (e,t) ->
    if 's' in @modes or 'i' in @modes
      Meteor.call 'mode', Meteor.user(), @name, '-si'
    else
      Meteor.call 'mode', Meteor.user(), @name, '+si'

  'click label.checkbox[for="showHideJoins"]': (e,t) ->
    if 'm' in @modes
      Meteor.call 'mode', Meteor.user(), @name, '-m'
    else
      Meteor.call 'mode', Meteor.user(), @name, '+m'
