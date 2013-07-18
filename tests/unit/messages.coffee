assert = require 'assert'

suite 'Messages', ->

  test 'Messages#type', (done, server, client) ->
    client.eval ->
      Accounts.createUser
        username: 'matt'
        password: 'password'
        profile:
          connecting: true
      , ->
        self = Messages.insert
          owner: Meteor.userId()
          from: 'matt'
          text: 'Hello!'

        mention = Messages.insert
          owner: Meteor.userId()
          from: 'bill'
          text: 'Hello matt!'

        normal = Messages.insert
          owner: Meteor.userId()
          from: 'bill'
          text: 'Hello!'

        emit 'check'
        , Messages.findOne(self).type()
        , Messages.findOne(mention).type()
        , Messages.findOne(normal).type()


    client.once 'check', (self, mention, normal) ->
      assert.equal self, 'self'
      assert.equal mention, 'mention'
      assert.equal normal, 'normal'
      done()

  test 'Messages#convo', (done, server, client) ->
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
          nicks: {'matt': '', 'bill': ''}

        noConvo = Messages.insert
          owner: Meteor.userId()
          from: 'bill'
          channel: '#channel'
          text: 'Hello!'

        convo = Messages.insert
          owner: Meteor.userId()
          from: 'bill'
          channel: '#channel'
          text: 'Hello matt!'

        emit 'check'
        , Messages.findOne(noConvo).convo()
        , Messages.findOne(convo).convo()

    client.once 'check', (noConvo, convo) ->
      assert.equal noConvo, ''
      assert.equal convo, 'matt'
      done()

  test 'Messages#online', (done, server) ->
    server.eval ->
      Channels.insert
        name: '#channel'
        nicks: {'doug': '', 'matt': ''}

      online = Messages.insert
        from: 'matt'
        channel: '#channel'
        text: 'Hello!'

      offline = Messages.insert
        from: 'bill'
        channel: '#channel'
        text: 'Hello!'

      emit 'check'
      , Messages.findOne(online).online()
      , Messages.findOne(offline).online()

    server.once 'check', (online, offline) ->
      assert.equal online, yes
      assert.equal offline, no
      done()
