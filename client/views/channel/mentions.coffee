Template.mentions.helpers
  mentions: ->
    Meteor.user().profile.channels[@name].mentions.length
  loadMore: ->
    limit = PERPAGE * Session.get('messages.page')
    messages = Messages.find({
      channel: @name
      convo: Meteor.user().username
    }, {limit, sort: {createdAt: -1}}).fetch()
    console.log messages.length
    console.log Messages.find().fetch().length
    messages.length < Messages.find({
      channel: @name
      convo: Meteor.user().username
    }).fetch().length

