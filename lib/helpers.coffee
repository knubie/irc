String::isChannel = ->
  /^[#](.*)$/.test @

@regex =
  url: /([-a-zA-Z0-9@:%_\+.~#?&//=]{2,256}\.[a-z]{2,4}\b(\/[-a-zA-Z0-9@:%_\+.~#?&//=]*)?)/ig
  code: /(^|<\/[^>]*>)([^<>]*)`([^<>]*)`([^<>]*)(?=$|<)/
  bold: /(^|<\/[^>]*>)([^<>]*)\*([^<>]*)\*([^<>]*)(?=$|<)/
  underline: /(^|<\/[^>]*>)([^<>]*)_([^<>]*)_([^<>]*)(?=$|<)/
  nick: (nick) -> new RegExp "(^|[^\\S])(#{nick})($|([:,.!?]|[^\\S]))"
