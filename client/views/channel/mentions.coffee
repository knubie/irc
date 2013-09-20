Template.mentions.helpers
  mentions: ->
    limit = PERPAGE * Session.get('messages.page')
    Messages.find({
      channel: @name
      convo: Meteor.user().username
    }, {limit, sort: {createdAt: -1}}).fetch().reverse()
    #(Messages.findOne(id) \
      #for id in Meteor.user().profile.channels[@name].mentions)
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

Template.mention.helpers
  timeAgo: ->
    moment(@createdAt).fromNow()
