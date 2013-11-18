nickPartialMatch = null
nickCurrentMatch = null
Template.say.events
  # Keydown triggers before the new character gets
  # inserted into the input field.
  'keyup #say': (e, t) ->
    keyCode = e.keyCode or e.which

    message = t.find('#say-input').value
    unless keyCode is 9 # Tab
      nickregex = /^(.*\s)*(\S*)$/
      nickPartialMatch = message.match nickregex
      nickCurrentMatch = null

    if keyCode is 13 # Enter
      e.preventDefault()
      nickPartialMatch = null

      $('#say-input').val('')

      # Server sends message to IRC before insert.
      if @channel? # Sending to channel
        Messages.insert
          channel: @channel.name
          text: message
          mobile: Modernizr.touch
          createdAt: new Date()
          from: Meteor.user().username
      else # Sending to user
        Messages.insert
          text: message
          mobile: Modernizr.touch
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
      nickregex = /^(.*\s)?(\S+)\s?$/
      if matches = message.match nickregex
        nicks = (nick for nick of @channel.nicks)
        if Session.equals('nickstart', null) # No previous nickstart
          Session.set 'nickstart', matches[2]
        #nickstart = new RegExp "^#{matches[2]}", 'i'
        for nick in nicks
          console.log nick
          console.log matches[2]
          if nick isnt matches[2] and nick.match(new RegExp("^#{Session.get('nickstart')}", 'i'))
            $('#say-input').val("#{matches[1] or ''}#{nick} ")
    else # Any other key
      Session.set 'nickstart', null

Template.say.rendered = ->
  # Auto-focus 'say' input.
  $('#say-input').focus() unless Modernizr.touch

  # Create array of nicks for autocomplete.
  nicks = ({username: nick} for nick of @channel?.nicks) ? []
  $('#say-input').mention
    delimiter: '@'
    sensitive: true
    queryBy: ['username']
    users: nicks

Template.say.helpers
  speakable: ->
    user = Meteor.user()
    @channel.hasUser(user.username) \
    and not @channel.isModerated() or (@channel.isModerated() and @channel.nicks[user.username] is '@')

