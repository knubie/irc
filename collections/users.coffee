# Users
# profile:
#   connection: Boolean
#   account: free/personal/business
#   channels: 
#     '#channelname':
#       ignore: [String, ...]
#       mode: String

if Meteor.isServer
  Accounts.validateNewUser (user) ->
    check user.username, String
    return true

  Accounts.validateNewUser (user) ->
    if /^[^\W]*$/.test user.username
      return true
    else
      throw new Meteor.Error 403, "Invalid characters in username."

  Accounts.validateNewUser (user) ->
    if user.username.length > 0
      return true
    else
      throw new Meteor.Error 403, "Username must have at least one character."

  Accounts.validateNewUser (user) ->
    if user.username.length < 10
      return true
    else
      throw new Meteor.Error 403, "Username must be less than 10 characters."
