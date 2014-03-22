nickregex = /^(.*\s)?(\S+)\s?$/
autoNickList = []
autoNickIndex = 0
Template.say.events
  # Keydown triggers before the new character gets
  # inserted into the input field.
  'keyup #say': (e, t) ->
    keyCode = e.keyCode or e.which
    message = t.find('#say-input').value

  'keydown #say': (e, t) ->
    keyCode = e.keyCode or e.which
    message = t.find('#say-input').value

    if keyCode is 13 # Enter
      e.preventDefault()
      nickPartialMatch = null

      $('#say-input').val('')

      # if /me action
      if /^\/me(.*)$/.test message
        Messages.insert
          channel: @channel.name
          text: "#{Meteor.user().username} #{message.replace /^\/me\s*/g, ''}"
          mobile: Modernizr.touch and $(window).width() < 768
          createdAt: new Date()
          from: Meteor.user().username
          type: 'action'
      else if /^\/msg(.*)$/.test message
        pmregex = /^\/msg\s(\S*)\s(.*)$/
        if pmregex.test message
          Messages.insert
            text: message.match(pmregex)[2]
            mobile: Modernizr.touch and $(window).width() < 768
            createdAt: new Date()
            from: Meteor.user().username
            to: message.match(pmregex)[1]
          Router.go('messages', {user: message.match(pmregex)[1]})
 
      else
        # Server sends message to IRC before insert.
        if @channel? # Sending to channel
          Messages.insert
            channel: @channel.name
            text: message
            mobile: Modernizr.touch and $(window).width() < 768
            createdAt: new Date()
            from: Meteor.user().username
        else # Sending to user
          Messages.insert
            text: message
            mobile: Modernizr.touch and $(window).width() < 768
            createdAt: new Date()
            from: Meteor.user().username
            to: @pm
    if keyCode is 9 # Tab
      e.preventDefault()
      # matches[0] == original message,
      # [1] == Everythig before the partial nick,
      # [2] == the partial nick.
      if matches = message.match nickregex
        if autoNickList.length < 1
          nicks = (nick for nick of @channel.nicks)
          autoNickList = nicks.filter (nick, i, arr) ->
            nick.match(new RegExp("^#{matches[2]}", 'i'))
          # append the original partial nick to the end of the list.
          autoNickList.push matches[2]

        if autoNickList.length > 1
          $('#say-input').val("#{matches[1] or ''}#{autoNickList[autoNickIndex]} ")
          if autoNickIndex < autoNickList.length - 1
            autoNickIndex++
          else
            autoNickIndex = 0

    else # Any other key
      i = 0
      autoNickList = []
      autoNickIndex = 0

Template.say.rendered = ->
  # Auto-focus 'say' input.
  $('#say-input').focus() unless Modernizr.touch

  # Create array of nicks for autocomplete.
  getName = (nick) ->
    Meteor.users.findOne({username: nick})?.profile.realName or ''
  channels = for channel in Channels.find().fetch()
    {username: channel.name.match(/^(.)(.*)$/)[2], delimiter: '#'}
  nicks = ({username: nick, name: getName(nick)} for nick of @data.channel?.nicks) ? []
  nicks.push channels
  nicks = _.flatten nicks
  #nicks.push {username: 'kick', delimiter: '/'}
  #nicks.push {username: 'msg', delimiter: '/'}
  $('#say-input').mention
    delimiter: '@'
    sensitive: true
    queryBy: ['name', 'username']
    emptyQuery: true
    typeaheadOpts:
      items: 10 # Max number of items you want to show
    users: nicks

Template.say.helpers
  speakable: ->
    user = Meteor.user()
    if @pm?
      true
    else if @channel?
      @channel.hasUser(user.username) \
      and not @channel.isModerated() \
      or (@channel.isModerated() and @channel.nicks[user.username] is '@')
    else
      false
