########## Messages ##########

Template.messages.rendered = ->
  # Keep scroll position when template rerenders,
  # especially if document height changes.
  $('.glyphicon-time').tooltip()
  #if Session.get('scroll') < 1
    #$(window).scrollTop 99999999

  $(window).scrollTop \
    $(document).height() - $(window).height() - Session.get('scroll')

  onImagesLoad
    each: ->
      console.log 'each'
      $(window).scrollTop \
        $(document).height() - $(window).height() - Session.get('scroll')
    final: ->
      'final'
      $(window).scrollTop \
        $(document).height() - $(window).height() - Session.get('scroll')

  #Hover isolates messages from like channels
  if @data.name is 'all'
    $('.message').hover ->
      $(".message").not("[data-channel='#{$(this).attr('data-channel')}']").addClass 'faded'
    , ->
      $('.message').removeClass 'faded'

  # Store nicks in an array
  else if @data.name.isChannel()
    nicks = (nick for nick of @data.nicks) ? []
  if Modernizr.touch
    $(window).on 'touchmove', updateStuff
  else
    $(window).scroll updateStuff

Template.messages.helpers
  messages: ->
    prev = null
    if @name is 'all'
      messages = Messages.find({}, {sort: {createdAt: 1}}).fetch()
    else
      messages = Messages.find(
        channel: @name
      , sort: {createdAt: 1}).fetch()
    setPrev = (msg) ->
      msg.prev = prev
      prev = msg
    if Meteor.user()
      return (setPrev message for message in messages when message.from \
      not in (Meteor.user().profile.channels[message.channel]?.ignore or []))
    else
      return (setPrev message for message in messages)
  channel: ->
    @name
  url_channel: ->
    @name.match(/^(#)?(.*)$/)[2]

########## Message ##########

Template.message.preserve ['iframe']
Template.message.rendered = ->
  # Get message text.
  p = $(@find('p'))
  ptext = p.html()
  # Linkify & Imagify URLs.
  ptext = ptext.replace regex.url, (str) ->
    #youtubeMatch = str.match regex.youtube
    if str.match /\.(?:jpe?g|gif|png)/
      "<a href=\"#{str}\" target=\"_blank\"><img src=\"#{str}\" alt=\"\"/></a>"
    #else if youtubeMatch and youtubeMatch[1].length is 11
      #"<iframe width=\"480\" height=\"360\" src=\"//www.youtube.com/embed/#{youtubeMatch[1]}\" frameborder=\"0\" allowfullscreen></iframe>"
    else
      "<a href=\"#{str}\" target=\"_blank\">#{str}</a>"
  #ptext = ptext.replace regex.image, "<img src=\"$&\" alt=\"\"/>"
  #while regex.url.test ptext
    #link_title = ''
    #url = ptext.match regex.url
    #$.ajax
        #url: "http://textance.herokuapp.com/title/#{url[0]}"
        #complete: (data) ->
          #link_title = data.responseText

    #ptext = ptext.replace regex.url, "<a href='$1' target='_blank'>link_title</a>"
  # Linkify nicks.
  if @data.channel.isChannel()
    for nick of Channels.findOne(name: @data.channel).nicks
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

  'click': (e, t) ->
    if Session.equals 'channel.name', 'all'
      # Slide toggle all messages not belonging to clicked channel
      # and set session to the new channel.
      $messagesFromOtherChannels = \
        $('.message').not("[data-channel='#{@channel}']")
      ch = Channels.findOne {name: @channel}
      # If there are any message to slideToggle...
      if $messagesFromOtherChannels.length > 0
        $messagesFromOtherChannels.slideToggle 400, =>
          Router.go "/channels/#{@channel.match(/^(#)?(.*)$/)[2]}"
      else # No messages to slideToggle
        Router.go "/channels/#{@channel.match(/^(#)?(.*)$/)[2]}"

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
    moment(@createdAt).fromNow()
  message_class: ->
    if @online() then @type() else "offline #{@type()}"
  op_status: ->
    if @channel.isChannel() and Meteor.user()
      Channels.findOne(name: @channel).nicks[Meteor.user().username] is '@'
  self: ->
    @type() is 'self'
  away: ->
    #TODO: make this change the user MODE in irc
    #TODO: add time since last online
    not Meteor.users.findOne(username: @from)?.profile.online
  awaySince: ->
    moment.duration((new Date()).getTime() - Meteor.users.findOne(username: @from)?.profile.awaySince).humanize()

Template.notification.timeAgo = ->
  moment(@createdAt).fromNow()

Template.notification.events
  'click, tap li': ->
    $(window).scrollTop $("##{@_id}").offset().top - 10

  'click .close': ->
    # Do something
