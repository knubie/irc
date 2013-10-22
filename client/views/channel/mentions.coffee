Template.channel_mentions.data = ->
  #console.log Channels.findOne(name:Session.get('channel.name'))
  Channels.findOne(name:Session.get('channel.name'))

########## Mentions ##########

Template.mentions.helpers
  mentions: ->
    limit = PERPAGE * Session.get('messages.page')
    Messages.find({
      channel: @name
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

########## Mention ##########

#Template.mention.rendered = ->
  #Messages.update @data._id, $set: {'read': true}

Template.mention.rendered = ->
  scrollToPlace() # Keep scroll position when template rerenders

  update Meteor.users, Meteor.userId()
  , "profile.channels.#{@data.channel}.mentions"
  , (mentions) =>
    _.reject mentions, (id) =>
      id is @data._id
  
  Meteor.setTimeout =>
    if isElementInViewport @find('.message')
      $(@find('.message')).removeClass('mention')
  , 10

  #update Meteor.users, Meteor.userId()
  #, "profile.channels.#{Session.get('channel.name')}.ignore"
  #, (ignore) => _.reject ignore, (nick) => nick is "#{@}"

Template.mention.events
  'click': ->
    Messages.update @_id, $set: {'read': true}

Template.mentions.events
  'click .load-more': (e,t) ->
    console.log 'load more'
    Session.set 'messages.page', Session.get('messages.page') + 1

Template.mention.helpers
  timeAgo: ->
    moment(@createdAt).fromNow()
  readClass: ->
    #if @_id in Meteor.user().profile.channels[@channel].mentions
      #return 'mention'
    #else
      #return ''
    'mention'
