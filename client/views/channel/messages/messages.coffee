regexps =
  code: regex.code
  url: regex.url
  channel: regex.channel

@gist = (data) ->
  id = data.div.slice(13, 20)
  $("##{id}").after('<br/>' + '<link rel="stylesheet" href="https://gist.github.com' + data.stylesheet + '">' + data.div)

parse = (str) ->
  strings = [{text: str}]
  for name, regexp of regexps
    for string, i in strings
      if not string.token? and matches = string.text.match regexp
        results = []
        start = 0
        for match in matches
          matchIndex = string.text.indexOf match

          first = string.text.slice start, matchIndex
          second = string.text.slice matchIndex, (matchIndex + match.length)
          third = string.text.slice (matchIndex + match.length)

          results.pop()
          results.push {text: first}
          results.push {text: second, token: name}
          results.push {text: third} if third.length > 0

          start = matchIndex + match.length

        strings[i] = results
        strings = _.flatten strings

  return strings

########## Messages ##########

Template.messages.rendered = ->
  # Set up AppScroll to mimic native scrolling iOS
  new AppScroll
    toolbar: document.getElementsByClassName('channel-header')[0]
    scroller: document.getElementsByClassName('messages')[0]
  .on()

  $('body').tooltip
    selector: '[data-toggle=tooltip]'
  # Set up listeners for scroll position
  if Modernizr.touch
    $(window).off 'touchmove'
    $(window).on 'touchmove', rememberScrollPosition
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

  $('.messages').bind 'DOMNodeInserted', ->
    scrollToPlace()

Template.messages.helpers
  messages: ->
    limit = (PERPAGE * Session.get('messages.page'))
    if @channel?
      selector = {channel: @channel.name}
    else if @pm?
      selector = {$or: [{to:@pm, from:Meteor.user().username}, {from:@pm, to:Meteor.user().username}]}
    else
      selector = {}
    if Meteor.user()? and @channel?
      selector.from =
        $nin: Meteor.user().profile.channels["#{@channel.name}"].ignore

    Messages.find selector, sort: createdAt: 1

  loadMore: ->
    true
    #TODO: loadMore loads the messages in reverse order as they are originally loaded.
    #limit = (PERPAGE * Session.get('messages.page'))
    #selector = if @channel? then {channel: @channel.name} else {}
    #Messages.find(selector).fetch().length == limit
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
  if @data.channel?
    # Remove mentions that are rendered.
    if (i = Meteor.user().profile.channels[@data.channel].mentions.indexOf(@data._id)) > -1
      update Meteor.users, Meteor.userId()
      , "profile.channels.#{@data.channel}.mentions"
      , (mentions) ->
        mentions.splice i, 1
        return mentions

  if @data.to is Meteor.user().username
    # Remove mentions that are rendered.
    if (i = Meteor.user().profile.pms[@data.from].unread.indexOf(@data._id)) > -1
      update Meteor.users, Meteor.userId()
      , "profile.pms.#{@data.from}.unread"
      , (unread) ->
        unread.splice i, 1
        return unread

  # Get message text.
  p = $(@find('p'))
  message = p.html()

  ptext = for string in parse(message)
    switch string.token
      when 'code'
        string.text.replace(/`([^`]*)`/g, "<code>$1</code>")
      when 'url'
        string.text.replace regexps.url, (str) =>
          youtubeMatch = str.match regex.youtube
          gistMatch = str.match regex.gist
          if Meteor.user().profile.inlineMedia and
          str.match /\.(?:jpe?g|gif|png)/i
            """
              <a href="#{str}" target="_blank">
                <img onload="scrollToPlace();" src="#{str}" alt=""/>
              </a>
            """
          else if youtubeMatch and
          youtubeMatch[1].length is 11 and
          Meteor.user().profile.inlineMedia
            "<iframe src=\"//www.youtube.com/embed/#{youtubeMatch[1]}\" frameborder=\"0\" allowfullscreen></iframe>"
          else if gistMatch and
          gistMatch[2].length is 7 and # or 20
          Meteor.user().profile.inlineMedia
            "<script id=\"#{gistMatch[2]}\" src=\"https://gist.github.com/#{gistMatch[1]}/#{gistMatch[2]}.json?callback=gist\"></script>"
          else # All other links
            "<a href=\"#{str}\" target=\"_blank\">#{str}</a>"
      when 'channel'
        string.text.replace(/#(\d*[a-zA-Z_]+)/g, '<a href="/channels/$1">#$1</a>')
      else
        if @data.channel?
          for nick of Channels.findOne(name: @data.channel).nicks
            string.text = string.text.replace regex.nick(nick), "$1<a href=\"/users/$2\">$2</a>$3"
        string.text.replace(/\*\*([^\*]*)\*\*/g, "<strong>$1</strong>")
        .replace(/\*([^\*]*)\*/g, "<em>$1</em>")
        .replace(/_([^_]*)_/g, '<span class="underline">$1</span>')

  p.html(ptext.join(''))

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

  'click': (e, t) -> #TODO: reimplement this
    if Session.equals('channel', null) and not $(e.target).is('strong')
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
            Router.go 'channel', {channel}
          else
            Router.go 'messages', {user:@from}
      else # No messages to slideToggle
        if @channel.isChannel()
          channel = @channel.match(/^(#)?(.*)$/)[2]
          Router.go 'channel', {channel}
        else
          Router.go 'messages', {user:@from}

  'click .convo': (e, t) ->
    $('.message')
    .not("[data-nick='#{@from}']")
    .not("[data-nick='#{@mentioned()[0]}']")
    .slideToggle 400
    #TODO: Hide messages mentioning other users.

  'click .kick': (e, t) ->
    Meteor.call 'kick', Meteor.user(), @channel, @from

  'click .ban': (e, t) ->
    if confirm("Are you sure you want to ban #{@from} from the channel? (You can un-ban them later in the channel settings.)")
      Meteor.call 'kick', Meteor.user(), @channel, @from, ''
      Meteor.call 'mode', Meteor.user(), @channel, '+b', @from
      update Channels, Channels.findOne({name: @channel})._id
      , "bans"
      , (bans) =>
        bans.push @from
        _.uniq bans

Template.message.helpers
  attrs: ->
    return {
      "id": @_id
      "data-nick": @from
      "data-channel": @channel
      "class": "message #{offline()} #{mention()} #{bot} #{info}"
    }
  joinToPrev: ->
    sameChannel = true
    mentioned = true
    prevMentioned = true
    messagesHandler = handlers.messages or handlers.allMessages
    if messagesHandler.ready()
      @prev = Messages.findOne
        createdAt:
          $lt: @createdAt
      ,
        sort:
          createdAt: -1
        limit: 1
    if @prev?.channel?
      sameChannel = @prev.channel is @channel
      mentioned = not @mentions(Meteor.user()?.username)
      prevMentioned = not @prev.mentions(Meteor.user()?.username)
    @prev? and @prev.from is @from \
    and sameChannel and mentioned and prevMentioned \
    and @from isnt 'system' and @type isnt 'action' \
    and @prev.type isnt 'action'
  timeAgo: ->
    timeAgoDep.depend()
    moment(@createdAt - TimeSync.serverOffset()).fromNow()
  offline: ->
    if @channel? \
    and @from isnt 'system' and @type isnt 'action' \
    and @from not of Channels.findOne({name: @channel})?.nicks
      return 'offline'
  banned: ->
    @channel? and @from in Channels.findOne({name: @channel})?.bans
  mention: ->
    if @convos? and Meteor.user()?.username in @convos
      return 'mention'
  op_status: ->
    if @channel? and Meteor.user()
      Channels.findOne(name: @channel).nicks[Meteor.user().username] is '@'
  operator: ->
    @channel? and Channels.findOne(name: @channel).nicks[@from] is '@'
  self: ->
    @from is 'system' or @from is Meteor.user()?.username or @type is 'action'
  info: ->
    if @from is 'system' or @type is 'action'
      return 'info'
  bot: ->
    if @from is 'Idletron'
      return 'bot'
  away: ->
    not Meteor.users.findOne(username: @from)?.status?.online
  awaySince: ->
    timeAgoDep.depend()
    moment.duration(new Date().getTime() - (Meteor.users.findOne(username: @from)?.status?.lastLogin - TimeSync.serverOffset())).humanize()
  reverseArrow: ->
    if @from is Meteor.user().username
      return 'reverse'
    else
      return ''
  isAll: ->
    !Session.get('channel') and @channel?
  realName: ->
    Meteor.users.findOne({username: @from})?.profile.realName
  touch: ->
    if Modernizr.touch
      'touch'
    else
      ''
