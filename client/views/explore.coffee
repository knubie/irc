Template.explore.events
  'click ul>li>h3>a': (e,t) ->
    name = e.toElement.outerText
    Meteor.call 'join', Meteor.user(), name
    ch = Channels.findOne {name}
    Session.set 'channel.name', name
    Session.set 'channel.id', ch._id
    $('#say-input').focus()

Template.explore.helpers
  channels: ->
    #TODO: exclude if not isChannel
    Channels.find {}, {sort : {users : -1}}
  url_name: ->
    @name.match(/^(.)(.*)$/)[2]

