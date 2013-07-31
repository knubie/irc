assert = require 'assert'

suite 'Integration:Connection', ->
  test 'Creating a user should sign that user in and connect to the network.', (done, server, client) ->
    server.eval ->
      Meteor.users.find().observeChanges
        added: (doc) ->
          emit 'done'

    client.eval ->
      Accounts.createUser
        username: 'matty'
        email: 'matty@gmail.com'
        password: 'password'
        profile:
          connection: off
          account: 'free'
      #$('#auth-nick').val('matty')
      #$('#auth-email').val('matty@gmail.com')
      #$('#auth-pw').val('password')
      #$('#form-signup').submit()

    server.once 'done', ->
      done()
