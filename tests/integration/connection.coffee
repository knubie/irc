assert = require 'assert'

serverHelpers = ->

clientHelpers = ->
  @signup = ->
    Accounts.createUser
      username: 'matty'
      email: 'matty@gmail.com'
      password: 'password'
      profile:
        connection: off
        account: 'free'
        channels: {}
    , (error) ->
      if Meteor.userId()? and not error
        Meteor.call 'remember', 'matty', 'password', Meteor.userId()

  emit 'return'

suite 'Integration', ->

  test 'Creating a user should sign that user in and connect to the network.', (done, server, client) ->

    client.evalSync clientHelpers

    client.evalSync ->
      Meteor.users.find().observe
        changed: (doc) ->
          if doc.profile.connection is on
            emit 'return'

      signup()

    done()
