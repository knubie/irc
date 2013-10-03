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

Template.say.rendered = ->
  $('#say-input').focus() unless Modernizr.touch
  if @data.name.isChannel()
    nicks = ({username: nick} for nick of @data.nicks) ? []
  $('#say-input').mention
    delimiter: '@'
    sensitive: true
    queryBy: ['username']
    users: nicks
