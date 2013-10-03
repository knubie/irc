Template.channel_main.rendered = ->
  if @data.name.isChannel()
    $set = {}
    $set["profile.channels.#{@data.name}.unread"] = []
    Meteor.users.update Meteor.userId(), {$set}
    #Messages.update {channel: @data.name, read: false}, {$set: {read: true}}
  #if window.webkitNotifications.checkPermission() is 1 and not Modernizr.touch
    #$('#notification-modal').modal
      #backdrop: true
      #keyboard: true

  if Meteor.user().profile.channels[@data.name].userList
    $('.user-list-container').show()
    $('.channel-container').removeClass('col-sm-9').addClass('col-sm-7')
    scrollToPlace() # Keep scroll position when template rerenders
  else
    $('.user-list-container').hide()
    $('.channel-container').removeClass('col-sm-7').addClass('col-sm-9')
    scrollToPlace() # Keep scroll position when template rerenders

Template.channel_main.events
  'click #notification-modal .btn-primary': ->
    webkitNotifications.requestPermission()

Template.channel_header.helpers
  channel: ->
    @name
  url_channel: ->
    @name.match(/^(#)?(.*)$/)[2]
  users: ->
    if @name.isChannel()
      @users
  topic: ->
    if @name.isChannel()
      @topic
  op_status: ->
    if @name.isChannel() and Meteor.user()
      @nicks[Meteor.user().username] is '@'
    else
      return no
  unread_mentions: ->
    Meteor.user().profile.channels[@name].mentions?.length or ''

Template.channel_header.events
  'click .topic-edit > a': (e, t) ->
    $('.topic').hide()
    $('#topic-form').show()
    $('#topic-name').focus()

  'click #topic-form > .cancel': (e, t) ->
    e.preventDefault()
    $('.topic').show()
    $('#topic-form').hide()

  'submit #topic-form': (e,t) ->
    e.preventDefault()
    topic = t.find('#topic-name').value
    Meteor.call 'topic', Meteor.user(), @_id, topic
    $('.topic').show()
    $('#topic-form').hide()

  'click .channel-invite': (e,t) ->
    $('#invite-username').focus()

  'submit #invite-form': (e,t) ->
    e.preventDefault()
    username = t.find('#invite-username').value
    Meteor.call 'invite', Meteor.user(), @name, username
    t.find('#invite-username').value = ''
    $('.invite-dropdown').dropdown('toggle')

  'click .dropdown-menu input': (e,t) -> e.stopPropagation()

  'click .user-count': (e,t) ->
    if $('.user-list-container').is(':visible')
      $set = {}
      $set["profile.channels.#{@name}.userList"] = false
      Meteor.users.update(Meteor.userId(), {$set})

      $('.user-list-container').hide()
      $('.channel-container').removeClass('col-sm-7').addClass('col-sm-9')
      scrollToPlace() # Keep scroll position when template rerenders
    else
      $set = {}
      $set["profile.channels.#{@name}.userList"] = true
      Meteor.users.update(Meteor.userId(), {$set})

      $('.user-list-container').show()
      $('.channel-container').removeClass('col-sm-9').addClass('col-sm-7')
      scrollToPlace() # Keep scroll position when template rerenders
      

########## Channels ##########

Template.channels.events
  'click .new-channel-link': (e, t) ->
    $('.new-channel-link').hide()
    $('.new-channel-form').show()
    $('.new-channel-input').focus()

  'blur .new-channel-input': (e, t) ->
    $('.new-channel-link').show()
    $('.new-channel-form').hide()

  'keydown .new-channel-input': (e, t) ->
    keyCode = e.keyCode or e.which
    if keyCode is 27
      $('.new-channel-link').show()
      $('.new-channel-form').hide()

  'submit .new-channel-form': (e, t) ->
    e.preventDefault()
    name = "#" + t.find('.new-channel-input').value
    t.find('.new-channel-input').value = ''
    if name
      Meteor.call 'join', Meteor.user().username, name, (err, channelId) ->
        if channelId
          Router.go "/channels/#{name.match(/^(.)(.*)$/)[2]}"
          $('#say-input').focus()

Template.channels.helpers
  channels: ->
    if Meteor.user()
      (channel for channel of Meteor.user().profile.channels)
    else
      [Session.get('channel.name')]
    #Channels.find
      #name: $in: (channel for channel of Meteor.user().profile.channels)
    #.fetch()
  pms: ->
    (pm for pm of Meteor.user().profile.pms)
  all: ->
    if Session.equals 'channel.name', 'all' then 'selected' else ''

########## Channel ##########

Template.channel.events
  'click a': (e,t) ->
    $('#say-input').focus() unless Modernizr.touch

  'click .close': ->
    Meteor.call 'part', Meteor.user().username, "#{@}"
    if "#{@}" is Session.get('channel.name')
      Router.go('home')

Template.channel.helpers
  selected: ->
    if Session.equals 'channel.name', "#{@}" then 'selected' else ''
  private: ->
    ch = Channels.findOne(name: "#{@}")
    if ch?
      's' in ch.modes or 'i' in ch.modes
    else
      no
  url_name: ->
    "#{@}".match(/^(.)(.*)$/)[2]
  unread: ->
    if Meteor.user()
      Meteor.user().profile.channels["#{@}"].unread.length or ''
  unread_mentions: ->
    if Meteor.user()
      Meteor.user().profile.channels["#{@}"].mentions?.length or ''

Template.pm.helpers
  selected: ->
    if Session.equals 'channel.name', "#{@}" then 'selected' else ''
  unread: ->
    Messages.find
      channel: "#{@}"
      read: false
    .fetch().length or ''
  #unread_mentions: ->
    #if Meteor.user()
      #ignore_list = Meteor.user().profile.channels["#{@}"].ignore
      #Messages.find
        #channel: "#{@}"
        #read: false
        #convo: Meteor.user().username
        #from: $nin: ignore_list
      #.fetch().length or ''
    #else
      #return ''
Template.pm.events
  'click .close': ->
    {pms} = Meteor.user().profile
    delete pms["#{@}"]
    Meteor.users.update Meteor.userId(), $set: {'profile.pms': pms}
    if "#{@}" is Session.get('channel.name')
      Router.go('home')

Template.users.helpers
  users: ->
    ({nick, flag} for nick, flag of @nicks).sort()
    #query = {}
    #query["profile.channels.#{@name}"] = {$exists: true}
    #Meteor.users.find(query)
  away: ->
    not Meteor.users.findOne({username: @nick})?.profile.online
  awaySince: ->
    moment.duration((new Date()).getTime() - Meteor.users.findOne(username: @nick)?.profile.awaySince).humanize()
