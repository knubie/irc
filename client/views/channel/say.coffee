Template.say.events
  'keydown #say': (e, t) ->
    #TODO: figure out a way to not have to disable autocomplete
    keyCode = e.keyCode or e.which
    message = t.find('#say-input').value
    if keyCode is 9 # Tab
      nickregex = /^(.*\s)*(\S*)$/
      if matches = message.match nickregex
        nicks = (nick for nick of @nicks)
        nickstart = new RegExp matches[2], 'i'
        for nick in nicks
          if nick.match nickstart
            e.preventDefault()
            $('#say-input').val("#{matches[1] or ''}#{nick}")

    if keyCode is 13 # Enter
      e.preventDefault()

      $('#say-input').val('')

      # Server sends message to IRC before insert.
      Messages.insert
        channel: @name
        text: message
        mobile: Modernizr.touch
        createdAt: new Date()
        from: Meteor.user().username

      #user = Meteor.user()

      #status =
        #'@': 'operator'
        #'': 'normal'

      #Messages.insert
        #from: user.username
        #channel: channel.name
        #text: message
        #createdAt: new Date()
        #convo: convo
        #status: if channel.nicks? then status[channel.nicks[user.username]] else 'normal'
        #read: true
        #mobile: Modernizr.touch

Template.say.rendered = ->
  $('#say-input').focus() unless Modernizr.touch
  if @data.name.isChannel()
    nicks = ({username: nick} for nick of @data.nicks) ? []
  $('#say-input').mention
    delimiter: '@'
    sensitive: true
    queryBy: ['username']
    users: nicks
