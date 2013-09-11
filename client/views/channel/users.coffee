########## Users ##########

Template.users.rendered = ->
  $('.glyphicon-time').tooltip()

Template.users.helpers
  users: ->
    ({nick, flag} for nick, flag of Channels.findOne(@_id).nicks).sort()
  away: ->
    not Meteor.users.findOne({username: @nick})?.profile.online
  awaySince: ->
    moment.duration((new Date()).getTime() - Meteor.users.findOne(username: @nick)?.profile.awaySince).humanize()
