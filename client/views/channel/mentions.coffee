########## Mentions ##########

Template.mentions.helpers
  mentions: ->
    Messages.find {},
      sort:
        createdAt: 1
      transform: (doc) ->
        if prev?._id is doc._id # Same doc.
          doc.prev = prev.prev # Re-assign `prev`
        else
          doc.prev = prev
          prev = new Message doc

        new Message doc
  loadMore: ->
    false
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
  #update Meteor.users, Meteor.userId()
  #, "profile.channels.#{@data.channel}.mentions"
  #, (mentions) =>
    #console.log 'remove mention'
    #_.reject mentions, (id) =>
      #id is @data._id

#Template.mention.events

Template.mention.helpers
  timeAgo: ->
    moment(@createdAt).fromNow()
  readClass: ->
    if @_id in Meteor.user().profile.channels[@channel].mentions
      return 'mention'
    else
      return ''
