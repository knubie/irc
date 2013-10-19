########## Mentions ##########

Template.mentions.helpers
  mentions: ->
    limit = PERPAGE * Session.get('messages.page')
    Messages.find({
      channel: @name
      convos: $in: [Meteor.user().username]
    }, {limit, sort: {createdAt: -1}}).fetch().reverse()
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

########## Mention ##########

#Template.mention.rendered = ->
  #Messages.update @data._id, $set: {'read': true}

Template.mention.events
  'click': ->
    Messages.update @_id, $set: {'read': true}

Template.mention.helpers
  timeAgo: ->
    moment(@createdAt).fromNow()
  readClass: ->
    if @read then '' else 'mention'
