// Generated by CoffeeScript 1.6.3
(function() {
  var assert;

  assert = require('assert');

  suite('Channels', function() {
    test('Channel#messages', function(done, server) {
      server["eval"](function() {
        Channels.insert({
          owner: '1',
          name: '#channel'
        });
        Messages.insert({
          owner: '1',
          channel: '#channel'
        });
        return emit('check', Channels.findOne().messages().fetch().length);
      });
      return server.once('check', function(length) {
        assert.equal(length, 1);
        return done();
      });
    });
    test('Channel#status', function(done, server, client) {
      client["eval"](function() {
        return Accounts.createUser({
          username: 'matt',
          password: 'password',
          profile: {
            connecting: true
          }
        }, function(err) {
          Channels.insert({
            owner: Meteor.userId(),
            name: '#channel',
            nicks: {
              'matt': '@'
            }
          });
          return emit('check', Channels.findOne().status());
        });
      });
      return client.once('check', function(status) {
        assert.equal(status, '@');
        return done();
      });
    });
    test('Channel#notifications', function(done, server, client) {
      client["eval"](function() {
        return Accounts.createUser({
          username: 'matt',
          password: 'password',
          profile: {
            connecting: true
          }
        }, function(err) {
          Channels.insert({
            owner: Meteor.userId(),
            name: '#channel'
          });
          Messages.insert({
            owner: Meteor.userId(),
            channel: '#channel',
            text: 'yo!'
          });
          Messages.insert({
            owner: Meteor.userId(),
            channel: '#channel',
            text: 'hey matt.'
          });
          return emit('check', Channels.findOne().notifications().length);
        });
      });
      return client.once('check', function(length) {
        assert.equal(length, 1);
        return done();
      });
    });
    test('insert', function(done, server, client) {
      client["eval"](function() {
        return Accounts.createUser({
          username: 'matt',
          password: 'password',
          profile: {
            connecting: true
          }
        }, function() {
          Channels.insert({
            owner: Meteor.userId(),
            name: '#channel'
          });
          return Channels.find().observe({
            added: function() {
              return emit('added');
            }
          });
        });
      });
      return client.once('added', function() {
        return done();
      });
    });
    test('uniqueness', function(done, server, client) {
      client["eval"](function() {
        return Accounts.createUser({
          username: 'matt',
          password: 'password',
          profile: {
            connecting: true
          }
        }, function() {
          Channels.insert({
            owner: Meteor.userId(),
            name: '#channel'
          });
          Channels.insert({
            owner: Meteor.userId(),
            name: '#channel'
          });
          return Channels.find().observe({
            removed: function() {
              return emit('removed');
            }
          });
        });
      });
      return client.once('removed', function() {
        return done();
      });
    });
    return test('no whitespace', function(done, server, client) {
      client["eval"](function() {
        return Accounts.createUser({
          username: 'matt',
          password: 'password',
          profile: {
            connecting: true
          }
        }, function() {
          Channels.insert({
            owner: Meteor.userId(),
            name: '#channel name'
          });
          return Channels.find().observe({
            removed: function() {
              return emit('removed');
            }
          });
        });
      });
      return client.once('removed', function() {
        return done();
      });
    });
  });

}).call(this);
