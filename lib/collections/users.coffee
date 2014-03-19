# Users
# profile:
#   account: free/personal/business
#   channels: 
#     '#channelname':
#       ignore: [String, ...]
#       mode: String

if Meteor.isServer
  #Accounts.config
    #sendVerificationEmail: true

  class User
    constructor: (doc) ->
      @[k] = doc[k] for k of doc
    join: (channel) ->
      newChannel = Channels.find_or_create(channel)
      # Join the channel in IRC.
      if Meteor.isServer
        unless 's' in newChannel.modes or 'i' in newChannel.modes
          client[username]?.join channel, async ->
            client.idletron.join channel

      if channel not of @profile.channels
        update Meteor.users, @_id
        , "profile.channels.#{channel}"
        , (channel) ->
          channel ?=
            ignore: []
            verbose: false
            unread: []
            mentions: []
            kicked: false

  Accounts.onCreateUser (options, user) ->
    # Create defaults
    profile =
      notifications: on
      sounds: on
      account: 'free'
      channels: {}
      pms: {}
      awaySince: 0
      realName: ''
      inlineMedia: true

    # Augment/override with client-side options
    _.extend profile, options.profile

    user.profile = profile
    return user

  Meteor.users.allow
    insert: -> false
    update: (userId, doc, fields, modifier) ->
      console.log 'user update'
      console.log fields
      if userId is doc._id and fields.every((f) -> f is 'sounds' or f is 'notifications' or f is 'realName')
        true
    remove: -> false
    
  Accounts.validateNewUser (user) ->
    check user.username, String
    return true

  Accounts.validateNewUser (user) ->
    if /^[^\W]*$/.test user.username
      return true
    else
      throw new Meteor.Error 403, "Invalid characters in username."

  Accounts.validateNewUser (user) ->
    if user.username.length > 0
      return true
    else
      throw new Meteor.Error 403, "Username must have at least one character."

  Accounts.validateNewUser (user) ->
    if user.username.length < 15
      return true
    else
      throw new Meteor.Error 403, "Username must be less than 15 characters."
