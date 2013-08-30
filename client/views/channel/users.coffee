########## Users ##########

Template.users.helpers
  users: ->
    ({nick, flag} for nick, flag of Channels.findOne(@_id).nicks).sort()
