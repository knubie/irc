Template.explore.helpers
  channels: ->
    Channels.find {}, {sort : {users : -1}}
  url: ->
    @name.match(/^(.)(.*)$/)[2]

Template.explore.events
  'click ul>li>h3>a': (e,t) ->
    name = e.toElement.outerText
    ch = Channels.findOne {name}
    Session.set 'channel.name', name
    Session.set 'channel.id', ch._id
    $('#say-input').focus()
