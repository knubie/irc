Template.say.events
  'keydown #say': (e, t) ->
    #TODO: figure out a way to not have to disable autocomplete
    keyCode = e.keyCode or e.which
    message = t.find('#say-input').value
    if keyCode is 9 # Tab
      nickregex = /^(.*\s)*(\S*)$/
      if matches = message.match nickregex
        nicks = (nick for nick of @channel.nicks)
        nickstart = new RegExp matches[2], 'i'
        for nick in nicks
          if nick.match nickstart
            e.preventDefault()
            $('#say-input').val("#{matches[1] or ''}#{nick}")

    if keyCode is 13 # Enter
      e.preventDefault()

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
          user: @pm
          text: message
          mobile: Modernizr.touch
          createdAt: new Date()
          from: Meteor.user().username
          owner: Meteor.userId()

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
