channelsHandle = Meteor.subscribe 'channels'
messagesHandle = Meteor.subscribeWithPagination 'messages', (-> Session.get('channel')), 50

Template.home.events
  'submit #auth-form': (e,t) ->
    e.preventDefault()
    username = t.find('#auth-nick').value
    password = t.find('#auth-pw').value

    if Meteor.users.findOne {username}
      Meteor.loginWithPassword username, password
    else
      Accounts.createUser
        username: username
        password: password
        profile:
          connecting: true
      , (err) ->
        Channels.insert
          owner: Meteor.userId()
          name: 'all'
        Meteor.apply 'newClient', [Meteor.user()]

Template.dashboard.connecting = ->
  return Meteor.user().profile.connecting

Template.channels.events
  'submit #new-channel': (e, t) ->
    e.preventDefault()
    name = t.find('#new-channel-name').value
    t.find('#new-channel-name').value = ''
    newChannel = Channels.insert
      owner: Meteor.userId()
      name: name
      nicks: []
    Meteor.apply 'join', [Meteor.user(), Channels.findOne newChannel]

Template.channels.channels = ->
  Channels.find {}

Template.channels.channel_selected = ->
  Session.get 'channel'

Template.channel.events
  'click li': (e,t) ->
    #FIXME: make this work for touch.
    Session.set 'channel', @name
    $('.nav > li > a > i').removeClass 'icon-white'
    $(e.currentTarget).find('i').addClass 'icon-white'

  'click .close': ->
    Channels.remove @_id
    Meteor.apply 'part', [Meteor.user(), @name]
    Session.set 'channel', 'all'

Template.channel.active = ->
  if Session.get('channel') is @name then 'active' else 'inactive'

Template.channel.alert_count = ->
  if @name is 'all'
    messages = Messages.find
      owner: Meteor.userId()
      alert: true
  else
    messages = Messages.find
      owner: Meteor.userId()
      to: @name
      alert: true
  count = messages.map((msg) -> msg).length
  if count > 0 then count else ''

Template.messages.rendered = ->
  ch = Channels.findOne
    owner: Meteor.userId()
    name: Session.get('channel')
  #FIXME: this breaks the messages.events
  #$('#say-input').typeahead
    #name: 'names'
    #local: [
      #'@matty'
      #'@oddmunds'
      #'@entel'
      #'@weezy'
      #'@costanza'
    #]
    #local: ch.nicks
  $(window).scrollTop(99999)

Template.messages.events
  'submit #say': (e, t) ->
    e.preventDefault()
    message = t.find('#say-input').value
    $('#say-input').val('')
    Meteor.apply 'say', [Meteor.user(), Session.get('channel'), message]
  'click .load-next': ->
    messagesHandle.loadNextPage()

Template.messages.channel = ->
  Session.get('channel')

Template.messages.messages = ->
  messages = Messages.find {}, sort: time: 1
  prev = null
  messages.map (msg) ->
    msg.prev = prev
    prev = msg

Template.messages.notifications = ->
  messages = Messages.find
    owner: Meteor.userId()
    to: Session.get('channel')
    type: 'mention'
  messages.map((msg) -> msg).reverse()

Template.message.rendered = ->
  urlExp = /(\b(https?|ftp|file):\/\/[-A-Z0-9+&@#\/%?=~_|!:,.;]*[-A-Z0-9+&@#\/%=~_|])/ig
  p = $(@find('p'))
  p.html(p.html().replace(urlExp,"<a href='$1' target='_blank'>$1</a>"))

Template.message.events
  'click .reply': ->
    $('#say-input').val("#{@from} ")
    $('#say-input').focus()

Template.message.joinToPrev = ->
  unless @prev is null
    @prev.from is @from

Template.message.all = ->
  Session.get('channel') is 'all'

Template.message.timeAgo = ->
  moment(@time).fromNow()

Meteor.setInterval ->
  $('.messages-container').html Meteor.render(Template.messages)
, 60000 # One minute

Template.message.message_class = ->
  ch = Channels.findOne {name: @to, owner: Meteor.userId()}
  status = 'offline'
  for nick in ch.nicks
    status = 'online' if @from is nick
  return status + ' ' + @type
  @type

Template.notifications.relativeTime = ->
  moment(@time).fromNow()

Template.notifications.events
  'click li': ->
    $(window).scrollTop $("##{@_id}").offset().top

  'click .close': ->
    Messages.update
      _id: @_id
    , {$set: {'type': 'normal'}}
