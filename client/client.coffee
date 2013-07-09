# Currently selected channel for viewing messages.
Session.setDefault 'channel', 'all'

# Collection subscriptions from the server.
channelsHandle = Meteor.subscribe 'channels'
messagesHandle = Meteor.subscribeWithPagination 'messages', (-> Session.get('channel')), 50

# Method stubs.
Meteor.methods
  join: (user, name) ->
    owner = user._id
    # If it's a channel, set an empty array and let the NAMES req populate it.
    # If not, it's a PM so set the nicks array to the current user and sender.
    nicks = if /^[#](.*)$/.test name then [] else [user.username, name]
    Channels.insert {owner, name, nicks}
  part: (user, channel) ->
    Channels.remove {owner: user._id, name: channel}
    #Messages.remove {owner: user._id, to: channel}
  say: (user, channel, message) ->
    Messages.insert
      from: user.username
      to: channel #TODO: perhaps change this to owner: channel._id
      text: message
      time: new Date
      owner: user._id
      type: 'self'

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

########## Channels ##########

Template.channels.channels = ->
  Channels.find {}

Template.channels.events
  'submit #new-channel': (e, t) ->
    e.preventDefault()
    name = t.find('#new-channel-name').value
    t.find('#new-channel-name').value = ''
    Meteor.apply 'join', [Meteor.user(), name]
    $('#say-input').focus()

  'click .channel': (e,t) ->
    #FIXME: make this work for touch.
    Session.set 'channel', @name
    $('#say-input').focus()

  'click .close': ->
    Meteor.apply 'part', [Meteor.user(), @name]
    Session.set 'channel', 'all'

Template.channels.selected = ->
  if Session.equals 'channel', @name then 'selected' else ''

Template.channels.alert_count = ->
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

########## Messages ##########
#
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

Template.messages.events
  'submit #say': (e, t) ->
    e.preventDefault()
    message = t.find('#say-input').value
    $('#say-input').val('')
    Meteor.apply 'say', [Meteor.user(), Session.get('channel'), message]

  'click .load-next': ->
    messagesHandle.loadNextPage()

$(window).scroll ->
  if $(window).scrollTop() < $(document).height() - $(window).height()
    Session.set 'scroll', true
  else
    Session.set 'scroll', false


Template.messages.rendered = ->
  if Session.equals 'channel', 'all'
    $('.message').hover ->
      $('.message').not("[data-channel='#{$(this).attr('data-channel')}']").css 'opacity', '0.3'
    , ->
      $('.message').css 'opacity', '1'
  if Session.equals 'scroll', false
    $(window).scrollTop($(document).height() - $(window).height())


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

Template.message.events
  'click .reply': ->
    $('#say-input').val("#{@from} ")
    $('#say-input').focus()

  'click': (e, t) ->
    if Session.equals 'channel', 'all'
      # Slide toggle all messages not belonging to clicked channel
      # and set session to the new channel.
      $('.message').not("[data-channel='#{@to}']").slideToggle 400, =>
        #Session.set 'channel', @to
        console.log 'hi'

Template.message.joinToPrev = ->
  unless @prev is null
    @prev.from is @from and @prev.to is @to

Template.message.all = ->
  Session.equals 'channel', 'all'

Template.message.timeAgo = ->
  moment(@time).fromNow()

#Meteor.setInterval ->
  #$('.messages-container').html Meteor.render(Template.messages)
#, 60000 # One minute

Template.message.message_class = ->
  ch = Channels.findOne {name: @to, owner: Meteor.userId()}
  status = 'offline'
  #FIXME: shouldn't need to check existence of ch
  if ch
    for nick in ch.nicks
      status = 'online' if @from is nick
    return status + ' ' + @type

Template.notifications.relativeTime = ->
  moment(@time).fromNow()

Template.notifications.events
  'click li': ->
    $(window).scrollTop $("##{@_id}").offset().top

  'click .close': ->
    Messages.update
      _id: @_id
    , {$set: {'type': 'normal'}}
