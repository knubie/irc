########## Messages ##########

Template.messages.rendered = ->
  # Set up listeners for scroll position
  if Modernizr.touch
    $(window).off 'touchmove'
    $(window).on 'touchmove', rememberScrollPosition
    $('.message').addClass('touch')
  $(window).off 'scroll'
  $(window).scroll rememberScrollPosition

  # Hover isolates messages from like channels
  unless @channel?
    $(document).on
      mouseenter: ->
        $(".message")
        .not("[data-channel='#{$(this).attr('data-channel')}']")
        .addClass 'faded'
      mouseleave: ->
        $('.message').removeClass 'faded'
    , '.message'

Template.messages.helpers
  messages: ->
    prev = null
    that = this
    selector = if @channel? then {channel: @channel.name} else {}
    #FIXME: this breaks the template engine.
    #if Meteor.user()? and @channel?
      #selector.from =
        #$nin: Meteor.user().profile.channels["#{@channel.name}"].ignore

    Messages.find selector,
      sort:
        createdAt: 1
      transform: (doc) ->
        # Sometimes transform gets called multiple times
        # when a new doc gets added. In that case, 'prev' and 'doc'
        # are the same object. We need to prevent docs
        # from assigning previous to themselves.
        if prev?._id is doc._id
          doc.prev = prev.prev
        else
          doc.prev = prev
          prev = new Message doc

        new Message doc
  loadMore: ->
    #true
    if @channel?
      Messages.find({channel: @channel.name}).length >= PERPAGE
    else
      Messages.find().length >= PERPAGE
  url_channel: ->
    @channel.name.match(/^(#)?(.*)$/)[2]

Template.messages.events
  'click .load-more': (e,t) ->
    Session.set 'messages.page', Session.get('messages.page') + 1

  'click .login-from-channel': (e,t) ->
    # Remember this channel so we can join it after logging in
    Session.set('joinAfterLogin', @channel.name)

########## Message ##########

Template.message.rendered = ->
  $('.glyphicon-time').tooltip()
  $('.glyphicon-phone').tooltip()

  # Get message text.
  p = $(@find('p'))
  ptext = p.html()
  # Linkify & Imagify URLs.
  ptext = ptext.replace regex.url, (str) ->
    youtubeMatch = str.match regex.youtube
    if str.match /\.(?:jpe?g|gif|png)/ # Image
      """
        <a href="#{str}" target="_blank">
          <img onload="scrollToPlace();" src="#{str}" alt=""/>
        </a>
      """
    else if youtubeMatch and youtubeMatch[1].length is 11
      "<iframe width=\"480\" height=\"360\" src=\"//www.youtube.com/embed/#{youtubeMatch[1]}\" frameborder=\"0\" allowfullscreen></iframe>"
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
  while regex.channel.test ptext
    ptext = ptext.replace regex.channel, ' <a href="/channels/$1">#$1</a>'
  p.html(ptext)

  scrollToPlace() # Keep scroll position when template rerenders

Template.message.events
  'click .reply-action': ->
    $('#say-input').val("@#{@from}")
    $('#say-input').focus()
    $('#say-input').trigger($.Event('keypress', {which: 13}))

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
            page "/channels/#{@channel.match(/^(#)?(.*)$/)[2]}"
          else
            page "/messages/#{@channel}"
      else # No messages to slideToggle
        if @channel.isChannel()
          page "/channels/#{@channel.match(/^(#)?(.*)$/)[2]}"
        else
          page "/messages/#{@channel}"

  'click .convo': (e, t) ->
    $('.message')
    .not("[data-nick='#{@from}']")
    .not("[data-nick='#{@mentioned()[0]}']")
    .slideToggle 400
    #TODO: Hide messages mentioning other users.

  'click .kick': (e, t) ->
    Meteor.call 'kick', Meteor.user(), @channel, @from

Template.message.helpers
  joinToPrev: ->
    @prev? \
    and @prev.channel is @channel \
    and @prev.from is @from \
    and not @mentions(Meteor.user()?.username) \
    and not @prev.mentions(Meteor.user()?.username)
  isConvo: ->
    mentions = []
    for nick of Channels.findOne(name:@channel).nicks
      if @mentions nick
        mentions.push nick
    mentions.length is 1
  timeAgo: ->
    moment(@createdAt).fromNow()
  offline: ->
    if @channel?.isChannel() \
    and @from not of Channels.findOne({name: @channel})?.nicks
      return 'offline'
  mention: ->
    if @mentions(Meteor.user()?.username)
      return 'mention'
  isMentioned: ->
    @mentions(Meteor.user().username)
  op_status: ->
    if @channel?.isChannel() and Meteor.user()
      Channels.findOne(name: @channel).nicks[Meteor.user().username] is '@'
  self: ->
    #@type() is 'self'
    false
  info: ->
    if @from is 'system'
      return 'info'
  bot: ->
    if @from is 'Idletron'
      return 'bot'
  away: ->
    #TODO: make this change the user MODE in irc
    Meteor.users.findOne({username: @nick}) \
    and not Meteor.users.findOne(username: @from)?.profile.online
  awaySince: ->
    moment.duration((new Date()).getTime() - Meteor.users.findOne(username: @from)?.profile.awaySince).humanize()
  isChannel: ->
    @channel?.isChannel()
  isAll: ->
    Session.equals('channel', null)
