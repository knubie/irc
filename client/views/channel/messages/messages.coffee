########## Messages ##########

Template.messages.rendered = ->
  $('body').tooltip
    selector: '[data-toggle=tooltip]'
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

  # Scroll to place
  Messages.find().observeChanges
    added: -> scrollToPlace()

  scrollToPlace()

Template.messages.helpers
  messages: ->
    limit = (PERPAGE * Session.get('messages.page'))
    prev = null
    if @channel?
      selector = {channel: @channel.name}
    else if @pm?
      selector = {$or: [{to:@pm, from:Meteor.user().username}, {from:@pm, to:Meteor.user().username}]}
    else
      selector = {}
    #FIXME: this breaks the template engine.
    if Meteor.user()? and @channel?
      selector.from =
        $nin: Meteor.user().profile.channels["#{@channel.name}"].ignore

    Messages.find selector,
      sort:
        createdAt: 1
      transform: (doc) ->
        # Sometimes transform gets called multiple times
        # when a new doc gets added. In that case, 'prev' and 'doc'
        # are the same object. We need to prevent docs
        # from assigning previous to themselves.
        if prev?._id is doc._id # Same doc.
          doc.prev = prev.prev # Re-assign `prev`
        else
          doc.prev = prev
          prev = new Message doc

        new Message doc

  loadMore: ->
    true
    #limit = (PERPAGE * Session.get('messages.page'))
    #selector = if @channel? then {channel: @channel.name} else {}
    #Messages.find(selector).fetch().length > limit 
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
  scrollToPlace()
  # Remove mentions that are rendered.
  if (i = Meteor.user().profile.channels[@data.channel].mentions.indexOf(@data._id)) > -1
    update Meteor.users, Meteor.userId()
    , "profile.channels.#{@data.channel}.mentions"
    , (mentions) ->
      mentions.splice i, 1
      return mentions

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

Template.message.events
  'click .reply-action': ->
    #FIXME: Chrome trims the trailing whitespace from the text input.
    $('#say-input').val("@#{@from} ")
    $('#say-input').focus()

  'click .ignore-action': ->
    if confirm("Are you sure you want to ignore #{@from}? (You can un-ignore them later in your channel settings.)")
      update Meteor.users, Meteor.userId()
      , "profile.channels.#{@channel}.ignore"
      , (ignore) =>
        ignore.push @from
        _.uniq ignore

  'click .reimplementme': (e, t) -> #TODO: reimplement this
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
            channel = @channel.match(/^(#)?(.*)$/)[2]
            Router.go 'channelPage', {channel}
          else
            Router.go "/messages/#{@from}"
      else # No messages to slideToggle
        if @channel.isChannel()
          channel = @channel.match(/^(#)?(.*)$/)[2]
          Router.go 'channelPage', {channel}
        else
          page "/messages/#{@channel}"
          Router.go "/messages/#{@from}"

  'click .convo': (e, t) ->
    $('.message')
    .not("[data-nick='#{@from}']")
    .not("[data-nick='#{@mentioned()[0]}']")
    .slideToggle 400
    #TODO: Hide messages mentioning other users.

  'click .kick': (e, t) ->
    console.log @
    Meteor.call 'kick', Meteor.user(), @channel, @from

  'click .ban': (e, t) ->
    if confirm("Are you sure you want to ban #{@from} from the channel? (You can un-ban them later in the channel settings.)")
      Meteor.call 'mode', Meteor.user(), @channel, '+b', @from
      update Channels, Channels.findOne({name: @channel})._id
      , "bans"
      , (bans) =>
        bans.push @from
        _.uniq bans

Template.message.helpers
  joinToPrev: ->
    sameChannel = true
    mentioned = true
    prevMentioned = true
    if @prev?.channel?
      sameChannel = @prev.channel is @channel
      mentioned = not @mentions(Meteor.user()?.username)
      prevMentioned = not @prev.mentions(Meteor.user()?.username)
    @prev? and @prev.from is @from \
    and sameChannel and mentioned and prevMentioned \
    and @from isnt 'system'
  isConvo: ->
    if @channel?
      mentions = []
      for nick of Channels.findOne(name:@channel).nicks
        if @mentions(nick)
          mentions.push nick
      mentions.length is 1 and @from isnt 'system'
    else
      false
  timeAgo: ->
    #moment(@createdAt).fromNow(true)
    ''
  offline: ->
    if @channel? \
    and @from not of Channels.findOne({name: @channel})?.nicks \
    and @from isnt 'system'
      return 'offline'
  banned: ->
    @channel? and @from in Channels.findOne({name: @channel})?.bans
  mention: ->
    if @mentions(Meteor.user()?.username)
      return 'mention'
  isMentioned: ->
    @channel? and @mentions(Meteor.user()?.username) and @from isnt 'system'
  op_status: ->
    if @channel?.isChannel() and Meteor.user()
      Channels.findOne(name: @channel).nicks[Meteor.user().username] is '@'
  operator: ->
    if @channel?.isChannel()
      if Channels.findOne(name: @channel).nicks[@from] is '@'
        return 'operator'
      else
        return ''
  self: ->
    #@type() is 'self'
    @from is 'system' or @from is Meteor.user()?.username
  info: ->
    if @from is 'system'
      return 'info'
  bot: ->
    if @from is 'Idletron'
      return 'bot'
  away: ->
    #TODO: make this change the user MODE in irc
    Meteor.users.findOne({username: @from}) \
    and not Meteor.users.findOne(username: @from).profile.online
  awaySince: ->
    moment.duration((new Date()).getTime() - Meteor.users.findOne(username: @from)?.profile.awaySince).humanize()
  isChannel: ->
    @channel?.isChannel()
  realName: ->
    Meteor.users.findOne(username:@from)?.profile.realName or ''
  reverseArrow: ->
    if @from is Meteor.user().username
      return 'reverse'
    else
      return ''
