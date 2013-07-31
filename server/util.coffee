@client = {}
@async = (cb) -> Meteor.bindEnvironment cb, (err) -> console.log err
