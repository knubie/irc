########## Messages ##########

Template.messages.rendered = ->
  Session.set('messages.rendered', true)

  $('.glyphicon-time').tooltip()

  scrollToPlace() # Keep scroll position when template rerenders

  # Set up listeners for scroll position
  if Modernizr.touch
    $(window).off 'touchmove'
    $(window).on 'touchmove', rememberScrollPosition
    $('.message').addClass('touch')
  $(window).off 'scroll'
  $(window).scroll rememberScrollPosition

  $(window).off 'resize'
  $('.message').each (i) ->
    el = @
    $(window).on 'resize scroll', ->
      doc = Messages.findOne($(el).attr('id'))
      if not doc.read and doc.from and isElementInViewport el
        Messages.update doc._id, $set: {'read': true}

  # Hover isolates messages from like channels
  if @data.name is 'all'
    $('.message').hover ->
      $(".message").not("[data-channel='#{$(this).attr('data-channel')}']").addClass 'faded'
    , -> $('.message').removeClass 'faded'

Template.messages.helpers
  messages: ->
    prev = null
    limit = PERPAGE * Session.get('messages.page')
    if @name is 'all'
      messages = Messages.find({}, {limit, sort: {createdAt: -1}}).fetch().reverse()
    else
      messages = Messages.find({
        channel: @name
      }, {limit, sort: {createdAt: -1}}).fetch().reverse()
    setPrev = (msg) ->
      msg.prev = prev
      prev = msg
    if Meteor.user()
      return (setPrev message for message in messages when message.from \
      not in (Meteor.user().profile.channels[message.channel]?.ignore or []))
    else
      return (setPrev message for message in messages)
  loadMore: ->
    limit = PERPAGE * Session.get('messages.page')
    if @name is 'all'
      messages = Messages.find({}, {limit, sort: {createdAt: -1}}).fetch().reverse()
      messagesTotal = Messages.find({}, {sort: {createdAt: -1}}).fetch().reverse()
    else
      messages = Messages.find({
        channel: @name
      }, {limit, sort: {createdAt: -1}}).fetch().reverse()
      messagesTotal = Messages.find({
        channel: @name
      }, {sort: {createdAt: -1}}).fetch().reverse()

    messages.length < messagesTotal.length
  channel: ->
    @name
  url_channel: ->
    @name.match(/^(#)?(.*)$/)[2]

Template.messages.events
  'click .load-more': (e,t) ->
    Session.set 'messages.page', Session.get('messages.page') + 1

########## Message ##########

Template.message.rendered = ->
  # Get message text.
  p = $(@find('p'))
  ptext = p.html()
  # Linkify & Imagify URLs.
  ptext = ptext.replace regex.url, (str) ->
    #youtubeMatch = str.match regex.youtube
    if str.match /\.(?:jpe?g|gif|png)/ # Image
      """
        <a href="#{str}" target="_blank">
          <img onload="scrollToPlace();" src="#{str}" alt=""/>
        </a>
      """
    #else if youtubeMatch and youtubeMatch[1].length is 11
      #"<iframe width=\"480\" height=\"360\" src=\"//www.youtube.com/embed/#{youtubeMatch[1]}\" frameborder=\"0\" allowfullscreen></iframe>"
    else # All other links
      "<a href=\"#{str}\" target=\"_blank\">#{str}</a>"
  # Linkify nicks.
  if @data.channel?.isChannel()
    for nick of Channels.findOne(name: @data.channel).nicks
      ptext = ptext.replace regex.nick(nick), "$1<a href=\"/users/$2\">$2</a>$3"
  # Markdownify other stuff.
  while regex.code.test ptext
    ptext = ptext.replace regex.code, '$1$2<code>$3</code>$4'
  while regex.bold.test ptext
    ptext = ptext.replace regex.bold, '$1$2<strong>$3</strong>$4'
  while regex.underline.test ptext
    ptext = ptext.replace regex.underline, '$1$2<span class="underline">$3</span>$4'
  p.html(ptext)

  #console.log "#{@data.text}: #{isElementInViewport @find('li')}"
  #if not @data.read and @data.from and isElementInViewport @find('li')
    #Messages.update @data._id, $set: {'read': true}

Template.message.events
  'click .reply-action': ->
    $('#say-input').val("@#{@from} ")
    $('#say-input').focus()

  'click .ignore-action': ->
    if confirm("Are you sure you want to ignore #{@from}? (You can un-ignore them later in your channel settings.)")
      {channels} = Meteor.user().profile
      channels[@channel].ignore.push @from
      channels[@channel].ignore = _.uniq channels[@channel].ignore
      Meteor.users.update Meteor.userId()
      , $set: {'profile.channels': channels}

  'click': (e, t) ->
    if Session.equals('channel.name', 'all') and not $(e.target).is('strong')
      # Slide toggle all messages not belonging to clicked channel
      # and set session to the new channel.
      $messagesFromOtherChannels = \
        $('.message').not("[data-channel='#{@channel}']")
      ch = Channels.findOne {name: @channel}
      # If there are any message to slideToggle...
      if $messagesFromOtherChannels.length > 0 and not Modernizr.touch
        $messagesFromOtherChannels.slideToggle 400, =>
          if @channel.isChannel()
            Router.go "/channels/#{@channel.match(/^(#)?(.*)$/)[2]}"
          else
            Router.go "/messages/#{@channel}"
      else # No messages to slideToggle
        if @channel.isChannel()
          Router.go "/channels/#{@channel.match(/^(#)?(.*)$/)[2]}"
        else
          Router.go "/messages/#{@channel}"

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
    if @from is 'Idletron'
      return 'bot'
    else
      if @online() then @type() else "offline #{@type()}"
  op_status: ->
    if @channel?.isChannel() and Meteor.user()
      Channels.findOne(name: @channel).nicks[Meteor.user().username] is '@'
  self: ->
    @type() is 'self'
  bot: ->
    @from is 'Idletron'
  away: ->
    #TODO: make this change the user MODE in irc
    not Meteor.users.findOne(username: @from)?.profile.online
  awaySince: ->
    moment.duration((new Date()).getTime() - Meteor.users.findOne(username: @from)?.profile.awaySince).humanize()
  isChannel: ->
    @channel?.isChannel()
