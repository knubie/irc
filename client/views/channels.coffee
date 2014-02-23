Template.channelHeader.helpers
  channelURL: ->
    @channel?.name.match(/^(#)?(.*)$/)[2]
  mentionsPath: ->
    Router.routes['mentions'].path({channel: @channel?.name.match(/^.(.*)$/)[1]})
  settingsPath: ->
    Router.routes['settings'].path({channel: @channel?.name.match(/^.(.*)$/)[1]})
  op_status: ->
    @channel?.nicks?[Meteor.user()?.username] is '@'
  unread_mentions: ->
    Meteor.user().profile.channels[@channel?.name]?.mentions?.length or ''
  mentionsActive: ->
    if Session.equals('subPage', 'mentions')
      return 'active'
    else
      return ''
  settingsActive: ->
    if Session.equals('subPage', 'settings')
      return 'active'
    else
      return ''

Template.channelHeader.events
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
    Meteor.call 'topic', Meteor.user(), @channel._id, topic
    $('.topic').show()
    $('#topic-form').hide()

  'click .channel-invite': (e,t) ->
    $('#invite-username').focus()

  'submit #invite-form': (e,t) ->
    e.preventDefault()
    username = t.find('#invite-username').value
    Meteor.call 'invite', Meteor.user(), @channel.name, username
    t.find('#invite-username').value = ''
    $('.invite-dropdown').dropdown('toggle')

  'click .dropdown-menu input': (e,t) -> e.stopPropagation()

  'click .user-count': (e,t) ->
    if $('.user-list-container').is(':visible')
      localStorage.setItem "#{@channel.name}.userList", false
      userListDep.changed()

      #scrollToPlace() # Keep scroll position when template rerenders
    else
      localStorage.setItem "#{@channel.name}.userList", true
      userListDep.changed()

      #scrollToPlace() # Keep scroll position when template rerenders

  'click .leave-channel': ->
    Meteor.call 'part', Meteor.user().username, @channel.name
    update Meteor.users, Meteor.userId()
    , "profile.channels"
    , (channels) =>
      delete channels[@channel.name]
      return channels
    Router.go 'home'
  
  'click .signout': ->
    #TODO: create some kind of explicit disconnect.
    #Meteor.call 'disconnect', Meteor.user().username
    Meteor.logout -> Router.go 'home'

      
########## Channels ##########

Template.channels.helpers
  channels: ->
    if Meteor.user()
      ({name: channel, channel: @channel} for channel of Meteor.user().profile.channels)
    else
      @channel.name
  pms: ->
    #(pm for pm of Meteor.user().profile.pms)
    ({name: user, pm: @pm} for user of Meteor.user().profile.pms)
  all: ->
    if @channel or @pm then '' else 'selected'

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
      Router.go 'channel', {channel: name.match(/^(.)(.*)$/)[2]}
      $('#say-input').focus()

########## Channel ##########

Template.channel.events
  'click a': (e,t) ->
    $('#say-input').focus() unless Modernizr.touch

  'click .close': ->
    Meteor.call 'part', Meteor.user().username, @name
    update Meteor.users, Meteor.userId()
    , "profile.channels"
    , (channels) =>
      delete channels[@name]
      return channels
    if @name is @channel.name
      Router.go 'home'

Template.channel.helpers
  selected: ->
    if @channel?.name is @name then 'selected' else ''
    #if Session.equals 'channel', @name then 'selected' else ''
  private: ->
    ch = Channels.findOne(name: @name)
    if ch?
      's' in ch.modes or 'i' in ch.modes
    else
      no
  readonly: ->
    ch = Channels.findOne(name: @name)
    if ch?
      'm' in ch.modes
    else
      no
  hashlessName: ->
    @name.match(/^(.)(.*)$/)[2]
  url: ->
    Router.routes['channel'].path({channel: @name.match(/^.(.*)$/)[1]})
  unread: ->
    Session.get("#{@name}.unread") or ''
  unread_mentions: ->
    if Meteor.user()
      Meteor.user().profile.channels[@name].mentions?.length or ''

Template.pm.helpers
  name: -> @name
  selected: ->
    #if Session.equals 'channel.name', "#{@}" then 'selected' else ''
    if @pm is @name then 'selected' else ''
  unread: ->
    Meteor.user().profile.pms[@name].unread?.length or ''
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
    delete pms[@name]
    Meteor.users.update Meteor.userId(), $set: {'profile.pms': pms}
    if @name is @pm
      Router.go 'home'

########## Settings ##########

Template.settings.helpers
  channelPath: ->
    Router.routes['channel'].path({channel: @channel.name.match(/^.(.*)$/)[1]})

########## Kicked ##########

Template.kicked.events
  'click .rejoin': ->
    console.log @channel.name
    update Meteor.users, Meteor.userId(), "profile.channels"
    , (channels) =>
      channels[@channel.name].kicked = no
      return channels
    Meteor.call 'join', Meteor.user().username, @channel.name


