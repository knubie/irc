# Currently selected channel for viewing messages.
Session.setDefault 'channel', 'all'
# Push messages to the bottom by default (ie don't save scroll position).
Session.setDefault 'scroll', false

Meteor.methods
  join: (user, name) ->
    owner = user._id
    # If it's a channel, set an empty array and let the NAMES req populate it.
    # If it's a PM, set the nicks array to the current user and sender.
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

# Collection subscriptions from the server.
handlers = {messages:{},channel:{}}
handlers.channel = Meteor.subscribe 'channels', ->
  channels = Channels.find()
  channels.forEach (channel) ->
    handlers.messages[channel.name] = Meteor.subscribeWithPagination 'messages'
    , channel.name
    , 10
  channels.rewind()
  channels.observe
    added: (channel) ->
      handlers.messages[channel.name] = Meteor.subscribeWithPagination 'messages'
      , channel.name
      , 10


#messagesHandle = Meteor.subscribeWithPagination 'messages', ->
  #Meteor.user().channels
#, 50

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
        Meteor.apply 'connect', [Meteor.user()]

Template.dashboard.connecting = ->
  return Meteor.user().profile.connecting

Template.dashboard.rendered = ->
  $(window).on 'keydown', (e) ->
    keyCode = e.keyCode or e.which
    if keyCode is 9 and not $('#say-input').is(':focus')
      e.preventDefault()
      $('#say-input').focus()

########## Channels ##########

Template.channels.channels = ->
  Channels.find()

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

Template.channels.notification_count = ->
  if @notifications() < 1 then '' else @notifications()

########## Messages ##########

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
    handlers.messages[Session.get 'channel'].loadNextPage()

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
  if Session.equals 'channel', 'all'
    messages = Messages.find {}, sort: time: 1
  else
    messages = Messages.find {to: Session.get('channel')}, sort: time: 1
  prev = null
  messages.map (msg) ->
    msg.prev = prev
    prev = msg

Template.messages.notifications = ->
  messages = Messages.find {type: 'mention'}, {sort: {time: 1}}

Template.message.rendered = ->
  # Define regular expressions.
  urlExp = /([-a-zA-Z0-9@:%_\+.~#?&//=]{2,256}\.[a-z]{2,4}\b(\/[-a-zA-Z0-9@:%_\+.~#?&//=]*)?)/ig
  codeExp = new RegExp "(^|</[^>]*>)([^<>]*)`([^<>]*)`([^<>]*)(?=$|<)"
  boldExp = new RegExp "(^|</[^>]*>)([^<>]*)\\*([^<>]*)\\*([^<>]*)(?=$|<)"
  underlineExp = new RegExp "(^|</[^>]*>)([^<>]*)_([^<>]*)_([^<>]*)(?=$|<)"
  # Get message text.
  p = $(@find('p'))
  ptext = p.html()
  # Linkify URLs.
  ptext = ptext.replace urlExp, "<a href='$1' target='_blank'>$1</a>"
  # Linkify nicks.
  ch = Channels.findOne {name: @data.to}
  #FIXME: shouldn't need to check existence of ch
  convo = ""
  if ch
    for nick in ch.nicks
      nickExp = new RegExp "(^|[^\\S])(#{nick})($|[^\\S])"
      ptext = ptext.replace nickExp, "$1<a href=\"#\">$2</a>$3"
  # Markdownify other stuff.
  ptext = ptext.replace codeExp, '$2<code>$3</code>$4'
  ptext = ptext.replace boldExp, '$2<strong>$3</strong>$4'
  ptext = ptext.replace underlineExp, '$2<span class="underline">$3</span>$4'
  p.html(ptext)

Template.message.events
  'click .reply': ->
    $('#say-input').val("#{@from} ")
    $('#say-input').focus()

  'click': (e, t) ->
    if Session.equals 'channel', 'all'
      # Slide toggle all messages not belonging to clicked channel
      # and set session to the new channel.
      $('.message').not("[data-channel='#{@to}']").slideToggle 400, =>
        Session.set 'channel', @to

  'click .convo': (e, t) ->
    convo = t.find('.message').getAttribute 'data-convo'
    # Slide toggle all messages not belonging to clicked channel
    # and set session to the new channel.
    #.not("[data-channel='#{@to}']") do this if in 'all'
    $('.message')
    .not("[data-nick='#{@from}']")
    .not("[data-nick='#{convo}']")
    .slideToggle 400

Template.message.joinToPrev = ->
  unless @prev is null
    @prev.from is @from and @prev.to is @to and @type isnt 'mention' and @prev.type isnt 'mention'

Template.message.all = ->
  Session.equals 'channel', 'all'

Template.message.convo = ->
  ch = Channels.findOne {name: @to}
  #FIXME: shouldn't need to check existence of ch
  convo = ""
  if ch
    for nick in ch.nicks
      nickExp = new RegExp "(^|[^\S])(#{nick})($|[^\S])"
      convo = "data-convo=#{nick}" if nickExp.test(@text)
  return convo

Template.message.isConvo = ->
  ch = Channels.findOne {name: @to}
  #FIXME: shouldn't need to check existence of ch
  convo = false
  if ch
    for nick in ch.nicks
      nickExp = new RegExp "(^|[^\S])(#{nick})($|[^\S])"
      convo = true if nickExp.test(@text)
  return convo

Template.message.timeAgo = ->
  moment(@time).fromNow()

Template.message.message_class = ->
  ch = Channels.findOne {name: @to}
  status = 'offline'
  #FIXME: shouldn't need to check existence of ch
  if ch
    for nick in ch.nicks
      status = 'online' if @from is nick
    return status + ' ' + @type

Template.notification.timeAgo = ->
  moment(@time).fromNow()

#Meteor.setInterval ->
  #$('.messages-container').html Meteor.render(Template.messages)
#, 60000 # One minute


Template.notification.events
  'click li': ->
    $(window).scrollTop $("##{@_id}").offset().top - 10

  'click .close': ->
    Messages.update
      _id: @_id
    , {$set: {'type': 'normal'}}
