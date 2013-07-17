assert = require 'assert'

suite 'IRC', ->
  test 'Integration', (done, server, client, client2) ->
    client.eval ->
      # Create a user.
      Accounts.createUser
        username: 'matty'
        password: 'password'
      , (err) ->
        # Connect user to IRC.
        Meteor.call 'connect', do ->
          Meteor.users.findOne username: 'matty'

    server.eval ->
      Meteor.users.find().observe
        added: (user) ->
          emit 'user:added', user
        changed: (user) ->
          if user.profile.connecting is true
            emit 'user:connecting', user
          else
            emit 'user:connected', user
            Meteor.call 'join', user, '##meteor_test'

      Channels.find().observe
        added: (channel) ->
          emit 'channel:added', channel
          Meteor.call 'say'
          , Meteor.users.findOne(username: 'matty')
          , channel.name, 'Hello'

      Messages.find().observe
        added: (message) ->
          emit 'message:added', message
          Meteor.call 'part'
          , Meteor.users.findOne(username: 'matty')
          , '##meteor_test'

        removed: (channel) ->
          emit 'channel:removed', channel

    server.once 'user:added', (user) ->
      assert.equal user.username, 'matty'
      console.log 'Created user.'

    server.on 'user:connecting', (user) ->
      assert.equal user.profile.connecting, true
      if user.username is 'matty'
        console.log 'Connecting user1...'
      else
        console.log 'Connecting user2...'

    server.on 'user:connected', (user) ->
      assert.equal user.profile.connecting, false
      if user.username is 'matty'
        client2.eval ->
          Accounts.createUser
            username: 'matty2'
            password: 'password'
            profile:
              connecting: false
          , (err) ->
            console.log 'Connecting 2nd user.'
            Meteor.call 'connect', do ->
              Meteor.users.findOne username: 'matty2'
        console.log 'User1 connected.'
      else
        console.log 'User2 connected.'
        Meteor.call 'join'
        , Meteor.users.findOne username:('matty2')
        , '##meteor_test'

    server.once 'channel:added', (channel) ->
      assert.equal channel.name, '##meteor_test'
      console.log 'Joined channel.'

    server.once 'message:added', (message) ->
      assert.equal message.text, 'Hello'
      assert.equal message.channel, '##meteor_test'
      assert.equal message.from, 'matty'
      #assert.equal message.type(), 'self'
      console.log 'Message sent.'

    server.once 'channel:removed', (channel) ->
      assert.equal channel.name, '##meteor_test'
      console.log 'Left channel.'
      done()
