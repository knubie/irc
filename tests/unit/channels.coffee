assert = require 'assert'

suite 'Channels', ->
  test 'uniqueness', (done, server, client) ->
    client.eval ->
      Accounts.createUser
        username: 'matt'
        password: 'password'
        profile:
          connecting: true
      , ->
        Channels.insert
          owner: Meteor.userId()
          name: '#channel'
        Channels.insert
          owner: Meteor.userId()
          name: '#channel'

        Channels.find().observe
          removed: -> emit 'removed'

    client.once 'removed', ->
      done()

  test 'no whitespace', (done, server, client) ->
    client.eval ->
      Accounts.createUser
        username: 'matt'
        password: 'password'
        profile:
          connecting: true
      , ->
        Channels.insert
          owner: Meteor.userId()
          name: '#channel name'

        Channels.find().observe
          removed: -> emit 'removed'

    client.once 'removed', ->
      done()

