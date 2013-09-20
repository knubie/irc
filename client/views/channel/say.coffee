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
      convo = ''
      for nick of @nicks
        if regex.nick(nick).test(message)
          convo = nick
          break

      status =
        '@': 'operator'
        '': 'normal'

      msgId = Messages.insert
        from: user.username
        channel: @name
        text: message
        #FIXME: use before hooks when they work with 0.6.5
        createdAt: (new Date()).getTime()
        owner: Meteor.userId()
        convo: convo
        status: if @nicks? then status[@nicks[user.username]] else 'normal'
        read: true
      #FIXME: user beforeInsert hook instead
      createdAt = Meteor.call 'date', (err, res) ->
        Messages.update msgId, $set: createdAt: res

Template.say.rendered = ->
  $('#say-input').focus() unless Modernizr.touch
  if @data.name.isChannel()
    nicks = ({username: nick} for nick of @data.nicks) ? []
  $('#say-input').mention
    delimiter: '@'
    sensitive: true
    queryBy: ['username']
    users: nicks
