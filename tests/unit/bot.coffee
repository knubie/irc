assert = require 'assert'

serverHelpers = ->
  @join = (channel) ->
    Meteor.users.find().observe
      changed: (doc) ->
        if channel of doc.profile.channels
          emit 'return'
    client['matty'].join(channel)

  emit 'return'

clientHelpers = ->
  @signup = ->
    Meteor.users.find().observe
      changed: (doc) ->
        if doc.profile.connection is on
          emit 'return'

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

  @join = (channel) ->
    Meteor.users.find().observe
      changed: (doc) ->
        if channel of doc.profile.channels
          emit 'return'
    Meteor.call 'join', Meteor.user().username, channel

  emit 'return'

suite 'Bot', ->

  test 'constructor', (done, server) ->
    bot = server.evalSync ->
      bot = new Client {_id: 1, username: 'matty', password: 'password'}
      emit 'return',
        _id: bot._id
        username: bot.username
        password: bot.password

    assert.equal bot._id, 1
    assert.equal bot.username, 'matty'
    assert.equal bot.password, 'password'
    done()

  test 'connect', (done, server, client) ->
    client.evalSync clientHelpers
    client.evalSync -> signup()
    done()

  test 'disconnect', (done, server, client) ->
    client.evalSync clientHelpers
    client.evalSync -> signup()

    server.evalSync ->
      Meteor.users.find().observe
        changed: (doc) ->
          if doc.profile.connection is off
            emit 'return'
      client['matty'].disconnect()

    done()

  test 'join', (done, server, client) ->
    server.evalSync serverHelpers
    client.evalSync clientHelpers
    client.evalSync -> signup()
    client.evalSync -> join('#test')
    done()

  test 'say', (done, server, client) ->
    server.evalSync serverHelpers
    client.evalSync clientHelpers

    client.evalSync -> signup()
    client.evalSync -> join('#test')

    text = server.evalSync ->
      Messages.find().observe
        added: (doc) ->
          emit 'return', doc.text
      client['matty'].say('#test', 'hello')

    assert.equal text, 'hello'
    done()

  test 'part', (done, server, client) ->
    server.evalSync serverHelpers
    client.evalSync clientHelpers

    client.evalSync -> signup()
    client.evalSync -> join('#test')

    server.evalSync ->
      Channels.find().observe
        removed: (doc) ->
          if doc.name is '#test'
            Meteor.users.update {name: 'matty'}
            , $set: {'profile.test': 'return'}
      Meteor.users.find().observe
        changed: (doc) ->
          if '#test' not of doc.profile.channels and doc.profile.test?
            emit 'return'
      client['matty'].part('#test')

    done()
