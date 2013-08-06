assert = require 'assert'

suite 'Channels', ->
  test 'find_or_create', (done, server) ->
    server.eval ->
      Channels.find_or_create '#test'
      doc = Channels.find_or_create '#test'
      docs = Channels.find().fetch()
      emit 'docs'#, doc, docs

    server.once 'docs', (doc, docs) ->
      #assert.equal doc.name, '#test'
      #assert.equal docs.length, 1
      done()
