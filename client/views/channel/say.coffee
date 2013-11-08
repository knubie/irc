nickPartialMatch = null
nickCurrentMatch = null
Template.say.events
  'keyup #say': (e, t) ->
    keyCode = e.keyCode or e.which

    message = t.find('#say-input').value
    unless keyCode is 9
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
    #TODO: figure out a way to not have to disable autocomplete
    keyCode = e.keyCode or e.which
    message = t.find('#say-input').value
    if keyCode is 13 # Enter
      e.preventDefault()
    if keyCode is 9 # Tab
      e.preventDefault()
      if nickPartialMatch?
        nicks = (nick for nick of @channel.nicks)
        nickstart = new RegExp nickPartialMatch[2], 'i'
        for nick in nicks
          console.log "nick in loop is #{nick}"
          console.log "nickCurrentMatch is #{nickCurrentMatch}"
          if nick isnt nickCurrentMatch and nick.match nickstart 
            console.log "nick(#{nick}) matches and isn't current(#{nickCurrentMatch})"
            e.preventDefault()
            $('#say-input').val("#{nickPartialMatch[1] or ''}#{nick} ")
            console.log "nickCurrentMatch = #{nick}"
            nickCurrentMatch = nick

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
