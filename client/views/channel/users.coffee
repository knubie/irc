@userListDep = new Deps.Dependency

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
    #query = {}
    #query["profile.channels.#{@name}"] = {$exists: true}
    #Meteor.users.find(query)
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
    moment.duration((new Date()).getTime() - Meteor.users.findOne(username: @nick)?.status?.lastLogin).humanize()
  mod: ->
    @flag is '@'
