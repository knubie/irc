assert = require 'assert'

suite 'Channels', ->
  test 'Channel#messages', (done, server) ->
    server.eval ->
      Channels.insert
        owner: '1'
        name: '#channel'
      Messages.insert
        owner: '1'
        channel: '#channel'
      emit 'check', Channels.findOne().messages().fetch().length

    server.once 'check', (length) ->
      assert.equal length, 1
      done()
        
  test 'Channel#status', (done, server, client) ->
    client.eval ->
      Accounts.createUser
        username: 'matt'
        password: 'password'
        profile:
          connecting: true
      , (err) ->
        Channels.insert
          owner: Meteor.userId()
          name: '#channel'
          nicks: {'matt': '@'}
        emit 'check', Channels.findOne().status()

    client.once 'check', (status) ->
      assert.equal status, '@'
      done()

  test 'Channel#notifications', (done, server, client) ->
    client.eval ->
      Accounts.createUser
        username: 'matt'
        password: 'password'
        profile:
          connecting: true
      , (err) ->
        Channels.insert
          owner: Meteor.userId()
          name: '#channel'
          notificationsRead: 1
        Messages.insert
          owner: Meteor.userId()
          channel: '#channel'
          text: 'yo!'
        Messages.insert
          owner: Meteor.userId()
          channel: '#channel'
          text: 'hey matt.'
        Messages.insert
          owner: Meteor.userId()
          channel: '#channel'
          text: 'hi again, matt.'
        emit 'check', Channels.findOne().notifications().length

    client.once 'check', (length) ->
      assert.equal length, 1
      done()

  test 'insert', (done, server, client) ->
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

        Channels.find().observe
          added: -> emit 'added'

    client.once 'added', ->
      done()

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

