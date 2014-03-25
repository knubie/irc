Handlebars.registerHelper 'userList', ->
  userListDep.depend()
  localStorage.getItem("#{Session.get 'channel'}.userList") is 'true'

Handlebars.registerHelper 'channelCol', ->
  userListDep.depend()
  if @channel? and localStorage.getItem("#{Session.get 'channel'}.userList") is 'true'
    '8'
  else
    '10'

Template.users.helpers
  users: ->
    if @channel?
      ({nick, realName: Meteor.users.findOne(username:nick)?.profile.realName, flag} for nick, flag of @channel.nicks).sort()
  away: ->
    Meteor.users.findOne({username: @nick}) \
    and not Meteor.users.findOne({username: @nick}).status?.online
    #Meteor.users.findOne({username: @nick})?.profile.online
  awayClass: ->
    if Meteor.users.findOne({username: @nick}) \
    and not Meteor.users.findOne({username: @nick}).status?.online
      return 'away'
    else
      return ''
  awaySince: ->
    timeAgoDep.depend()
    moment.duration(
      new Date().getTime() - (
        Meteor.users.findOne(
          username: @nick
        )?.status?.lastLogin - TimeSync.serverOffset()
      )
    ).humanize()
  mod: ->
    @flag is '@'
  path: ->
    Router.routes.user.path(user: @nick)

