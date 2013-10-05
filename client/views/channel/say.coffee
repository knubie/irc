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
      Meteor.call 'say', Meteor.user().username, @name, message
      user = Meteor.user()
      channel = Channels.findOne({name: @name})
      convo = ''
      for nick of channel.nicks
        if regex.nick(nick).test(message)
          convo = nick
          break

      status =
        '@': 'operator'
        '': 'normal'

      Messages.insert
        from: user.username
        channel: channel.name
        text: message
        createdAt: new Date()
        owner: Meteor.userId()
        convo: convo
        status: if channel.nicks? then status[channel.nicks[user.username]] else 'normal'
        read: true

Template.say.rendered = ->
  $('#say-input').focus() unless Modernizr.touch
  if @data.name.isChannel()
    nicks = ({username: nick} for nick of @data.nicks) ? []
  $('#say-input').mention
    delimiter: '@'
    sensitive: true
    queryBy: ['username']
    users: nicks
