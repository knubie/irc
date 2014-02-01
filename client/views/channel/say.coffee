nickregex = /^(.*\s)?(\S+)\s?$/
autoNickList = []
autoNickIndex = 0
Template.say.events
  # Keydown triggers before the new character gets
  # inserted into the input field.
  'keyup #say': (e, t) ->
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

  'keydown #say': (e, t) ->
    keyCode = e.keyCode or e.which
    message = t.find('#say-input').value

    if keyCode is 13 # Enter
      e.preventDefault()
    if keyCode is 9 # Tab
      e.preventDefault()
      # matches[0] == original message, [1] == Everythig before the partial nick, [2] == the partial nick.
      if matches = message.match nickregex
        if autoNickList < 1
          nicks = (nick for nick of @channel.nicks)
          autoNickList = nicks.filter (nick, i, arr) ->
            nick.match(new RegExp("^#{matches[2]}", 'i'))
          autoNickList.push matches[2] # append the original partial nick to the end of the list.

        $('#say-input').val("#{matches[1] or ''}#{autoNickList[autoNickIndex]} ")
        if autoNickIndex < autoNickList.length - 1
          autoNickIndex ++
        else
          autoNickIndex = 0

    else # Any other key
      i = 0
      autoNickList = []

Template.say.rendered = ->
  # Auto-focus 'say' input.
  $('#say-input').focus() unless Modernizr.touch

  # Create array of nicks for autocomplete.
  nicks = ({username: nick} for nick of @data.channel?.nicks) ? []
  $('#say-input').mention
    delimiter: '@'
    sensitive: true
    queryBy: ['username']
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

