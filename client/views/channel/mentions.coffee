########## Mentions ##########

Template.mentions.helpers
  mentions: ->
    limit = PERPAGE * Session.get('messages.page')
    Messages.find({
      channel: @channel.name
      convos: $in: [Meteor.user().username]
    }, {limit, sort: {createdAt: -1}}).fetch().reverse()
  loadMore: ->
    true
    #limit = PERPAGE * Session.get('messages.page')
    #messages = Messages.find({
      #channel: @name
      #convo: Meteor.user().username
    #}, {limit, sort: {createdAt: -1}}).fetch()
    #console.log messages.length
    #console.log Messages.find().fetch().length
    #messages.length < Messages.find({
      #channel: @name
      #convo: Meteor.user().username
    #}).fetch().length

#Template.mention.rendered = ->
  #Messages.update @data._id, $set: {'read': true}

Template.mentions.rendered = ->
  scrollToPlace() # Keep scroll position when template rerenders

Template.mentions.events
  'click .load-more': (e,t) ->
    Session.set 'messages.page', Session.get('messages.page') + 1

########## Mention ##########

Template.mention.rendered = ->
  update Meteor.users, Meteor.userId()
  , "profile.channels.#{@data.channel}.mentions"
  , (mentions) =>
    _.reject mentions, (id) =>
      id is @data._id
  #update Meteor.users, Meteor.userId()
  #, "profile.channels.#{Session.get('channel.name')}.ignore"
  #, (ignore) => _.reject ignore, (nick) => nick is "#{@}"

Template.mention.events
  'click': ->
    Messages.update @_id, $set: {'read': true}

Template.mention.helpers
  timeAgo: ->
    moment(@createdAt).fromNow()
  readClass: ->
    if @_id in Meteor.user().profile.channels[@channel].mentions
      return 'mention'
    else
      return ''
