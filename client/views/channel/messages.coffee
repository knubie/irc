########## Messages ##########

Template.messages.rendered = ->
  if Session.equals 'channel.name', 'all'
    $('.message').hover ->
      $(".message").not("[data-channel='#{$(this).attr('data-channel')}']").addClass 'faded'
    , ->
      $('.message').removeClass 'faded'
  else if Session.get('channel.name').isChannel()
    ch = Channels.findOne Session.get('channel.id')
    nicks = (nick for nick of ch?.nicks) ? []
    #$('#say-input').typeahead
      #name: 'names'
      #local: nicks
  # Keep scroll position when template rerenders,
  # especially if document height changes.
  $(window).scrollTop \
    $(document).height() - $(window).height() - session.get('scroll')

template.messages.events
  'click, tap .load-next': ->
    handlers.messages[Session.get 'channel.name'].loadNextPage()

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
    Meteor.call 'topic', Meteor.user(), Session.get('channel.id'), topic
    $('.topic').show()
    $('#topic-form').hide()

Template.messages.helpers
  messages: ->
    prev = null
    if Session.equals 'channel.name', 'all'
      messages = Messages.find({}, {sort: {time: 1}}).fetch()
    else
      messages = Messages.find(
        channel: Session.get 'channel.name'
      , sort: {time: 1}).fetch()
    setPrev = (msg) ->
      msg.prev = prev
      prev = msg
    if Meteor.user()
      return (setPrev message for message in messages when message.from \
      not in (Meteor.user().profile.channels[message.channel]?.ignore or []))
    else
      return (setPrev message for message in messages)
  topic: ->
    if Session.get('channel.name').isChannel()
      Channels.findOne(Session.get 'channel.id')?.topic
  op_status: ->
    if Session.get('channel.name').isChannel() and Meteor.user()
      Channels.findOne(Session.get 'channel.id')?.nicks[Meteor.user().username] is '@'
    else
      return no
  channel: ->
    Session.get 'channel.name'
  url_channel: ->
    Session.get('channel.name').match(/^(#)?(.*)$/)[2]
  users: ->
    if Session.get('channel.name').isChannel()
      Channels.findOne(Session.get 'channel.id')?.users

########## Message ##########

Template.message.rendered = ->
  # Get message text.
  p = $(@find('p'))
  ptext = p.html()
  # Linkify URLs.
  ptext = ptext.replace regex.url, "<a href='$1' target='_blank'>$1</a>"
  # Linkify nicks.
  if @data.channel.isChannel()
    for nick, status of Channels.findOne(name: @data.channel).nicks
      ptext = ptext.replace regex.nick(nick), "$1<a href=\"#\">$2</a>$3"
  # Markdownify other stuff.
  while regex.code.test ptext
    ptext = ptext.replace regex.code, '$1$2<code>$3</code>$4'
  while regex.bold.test ptext
    ptext = ptext.replace regex.bold, '$1$2<strong>$3</strong>$4'
  while regex.underline.test ptext
    ptext = ptext.replace regex.underline, '$1$2<span class="underline">$3</span>$4'
  p.html(ptext)

  if not @data.read and @data.from
    Messages.update @data._id, $set: {'read': true}

Template.message.events
  'click .reply-action': ->
    $('#say-input').val("@#{@from} ")
    $('#say-input').focus()

  'click .ignore-action': ->
    #TODO: extract this pattern into an update method
    {channels} = Meteor.user().profile
    channels[@channel].ignore.push @from
    channels[@channel].ignore = _.uniq channels[@channel].ignore
    Meteor.users.update Meteor.userId()
    , $set: {'profile.channels': channels}

  'click, tap': (e, t) ->
    if Session.equals 'channel.name', 'all'
      # Slide toggle all messages not belonging to clicked channel
      # and set session to the new channel.
      $messagesFromOtherChannels = \
        $('.message').not("[data-channel='#{@channel}']")
      ch = Channels.findOne {name: @channel}
      # If there are any message to slideToggle...
      if $messagesFromOtherChannels.length > 0
        $messagesFromOtherChannels.slideToggle 400, =>
          Session.set 'channel.name', @channel
          Session.set 'channel.id', ch._id
      else # No messages to slideToggle
        Session.set 'channel.name', @channel
        Session.set 'channel.id', ch._id

  'click .convo': (e, t) ->
    $('.message')
    .not("[data-nick='#{@from}']")
    .not("[data-nick='#{@convo}']")
    .slideToggle 400

  'click .kick': (e, t) ->
    Meteor.call 'kick', Meteor.user(), @channel, @from

Template.message.helpers
  joinToPrev: ->
    unless @prev is null
      @prev.from is @from and @prev.channel is @channel and @type() isnt 'mention' and @prev.type() isnt 'mention'
  isConvo: ->
    if @convo then yes else no
  timeAgo: ->
    moment(@time).fromNow()
  message_class: ->
    if @online() then @type() else "offline #{@type()}"
  op_status: ->
    if @channel.isChannel() and Meteor.user()
      Channels.findOne(name: @channel).nicks[Meteor.user().username] is '@'
  self: ->
    @type() is 'self'

Template.notification.timeAgo = ->
  moment(@time).fromNow()

Template.notification.events
  'click, tap li': ->
    $(window).scrollTop $("##{@_id}").offset().top - 10

  'click .close': ->
    # Do something

