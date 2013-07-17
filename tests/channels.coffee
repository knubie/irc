assert = require 'assert'

suite 'Channels', ->
  test 'duplication', (done, server) ->
    server.eval ->
      Channels.insert name: '#meteor'
      docs = Channels.find().fetch()
      emit('docs', docs)

    server.once 'docs', (docs) ->
      assert.equal(docs.length, 1)
      done()
