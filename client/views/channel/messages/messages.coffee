########## Messages ##########

Template.messages.rendered = ->
  $('.glyphicon-time').tooltip()
  $('.glyphicon-phone').tooltip()

  #scrollToPlace() # Keep scroll position when template rerenders
  $(window).scrollTop $(document).height()

  # Set up listeners for scroll position
  if Modernizr.touch
    $(window).off 'touchmove'
    $(window).on 'touchmove', rememberScrollPosition
    $('.message').addClass('touch')
  $(window).off 'scroll'
  $(window).scroll rememberScrollPosition

  # Hover isolates messages from like channels
  if @data.name is 'all'
    $('.message').hover ->
      $(".message").not("[data-channel='#{$(this).attr('data-channel')}']").addClass 'faded'
    , -> $('.message').removeClass 'faded'

Template.messages.helpers
  messages: ->
    prev = null
    notIn = { $nin: Meteor.user().profile.channels["#{@name}"].ignore }
    selector = if @name is 'all' then {from: notIn} else {channel: @name, from: notIn}

    Messages.find selector,
      sort:
        createdAt: 1
      transform: (doc) ->
        doc.mentions = (user) ->
          regex.nick(user).test(@text)
        doc.mentioned = ->
          mentions = []
          for nick of Channels.findOne(name:@channel).nicks
            if @mentions nick
              mentions.push nick
          return mentions

        unless prev?._id is doc._id
          doc.prev = prev
          prev = doc

        return doc

    #setPrev = (msg) ->
      #msg.prev = prev
      #prev = msg
    #if Meteor.user()
      #Session.set 'messages', (setPrev message for message in messages when message.from \
      #not in (Meteor.user().profile.channels[message.channel]?.ignore or []))
    #else
      #Session.set 'messages', (setPrev message for message in messages)

    #return messages
  loadMore: ->
    #true
    if @name is 'all'
      Messages.find().length >= PERPAGE
    else
      Messages.find({channel: @name}).length >= PERPAGE
  channel: ->
    @name
  url_channel: ->
    @name.match(/^(#)?(.*)$/)[2]

Template.messages.events
  'click .load-more': (e,t) ->
    Session.set 'messages.page', Session.get('messages.page') + 1

  'click .login-from-channel': (e,t) ->
    # Remember this channel so we can join it after logging in
    Session.set('joinAfterLogin', @name)

########## Message ##########

Template.message.rendered = ->
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

  'click .kick': (e, t) ->
    Meteor.call 'kick', Meteor.user(), @channel, @from

Template.message.helpers
  joinToPrev: ->
    @prev isnt null \
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
