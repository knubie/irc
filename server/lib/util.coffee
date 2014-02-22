parseString = Meteor.require('xml2js').parseString
request = Npm.require('request')
Cleverbot = Meteor.require('cleverbot-node')
@cleverbot = new Cleverbot
@client = {}
@async = (cb) -> Meteor.bindEnvironment cb, (err) -> console.log err
@wolfram = {}

wolfram.request = (query, callback) ->
  URL = "http://api.wolframalpha.com/v2/query?input=#{encodeURIComponent(query)}&appid=AQLTXA-LU46J2XQ92"

  request URL, async (error, response, body) ->
    if !error and response.statusCode == 200
      # Convert XML response to json
      parseString body, async (error, result) ->
        if result.queryresult.didyoumeans?
          newQuery = result.queryresult.didyoumeans[0].didyoumean[0]._
          #response "Did you mean #{newQuery}?"
          callback false
        else
          if result.queryresult.pod?
            for pod, i in result.queryresult.pod
              unless i is 0 or _.isEmpty pod.subpod[0].plaintext[0]
                if typeof(pod.subpod[0].plaintext) is "object"
                  callback(pod
                    .subpod[0]
                    .plaintext[0]
                    .replace(/\s+\|/g, ':')
                    .replace(/\n/g, ' | '))
                else
                  callback(pod
                    .subpod[0]
                    .plaintext
                    .replace(/\s+\|/g, ':')
                    .replace(/\n/g, ' | '))
                break
          else
            callback false
