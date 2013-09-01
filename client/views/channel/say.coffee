Template.say.events
  'keydown #say': (e, t) ->
    keyCode = e.keyCode or e.which
    if keyCode is 13
      e.preventDefault()
      message = t.find('#say-input').value
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
      createdAt = Meteor.call 'date', (err, res) ->
        Messages.update msgId, $set: createdAt: res

Template.say.rendered = ->
  $('#say-input').focus()
  if @data.name.isChannel()
    nicks = (nick for nick of @data.nicks) ? []
  $('#say-input').typeahead
    name: 'names'
    local: nicks
