net  = Npm.require 'net'
tls  = Npm.require 'tls'
util = Npm.require 'util'

class Client
  constructor: (server, nick, opt) ->
    self = this

    @opt =
      server: server
      nick: nick
      password: null
      userName: 'nodebot'
      realName: 'nodeJS IRC client'
      port: 6667
      debug: false
      showErrors: false
      autoRejoin: true
      autoConnect: true
      channels: []
      retryCount: null
      retryDelay: 2000
      secure: false
      selfSigned: false
      certExpired: false
      floodProtection: false
      floodProtectionDelay: 1000
      stripColors: false
      channelPrefixes: "&#"
      messageSplit: 512

    # Features supported by the server
    # (initial values are RFC 1459 defaults. Zeros signify
    # no default or unlimited value)
    @supported =
      channel:
        idlength: []
        length: 200
        limit: []
        modes: { a: '', b: '', c: '', d: ''}
        types: self.opt.channelPrefixes
      kicklength: 0
      maxlist: []
      maxtargets: []
      modes: 3
      nicklength: 9
      topiclength: 0
      usermodes: ''

    if typeof arguments[2] == 'object'
      #@opt extends arguments[2]
      for key of arguments[2]
        @opt[key] = arguments[2][key]

    if @opt.floodProtection
      self.activateFloodProtection()

    if @opt.autoConnect
      self.connect()

    @addListener 'raw', (message) =>
      switch message.command
        when '001' then
          # Set nick to whatever the server decided it really is
          # (normally this is because you chose something too long and
          # the server has shortened it
          @nick = message.args[0]
          @emit 'registered', message
          break
        when '002' then
        when '003' then
        when 'rpl_myinfo' then
          @supported.usermodes = message.args[3]
          break
        when 'rpl_isupport' then
          for arg in message.args
            if match = arg.match(/([A-Z]+)=(.*)/)
              param = match[1]
              value = match[2]
              switch param
                when 'CHANLIMIT' then
                  for val in value.split(',')
                    val = val.split(':')
                    self.supported.channel.limit[val[0]] = parseInt(val[1])
                  break
                when 'CHANMODES' then
                  value = value.split(',')
                  type = ['a','b','c','d']
                  for t, i in type
                    @supported.channel.modes[t] += value[i]
                  break
                when 'CHANTYPES' then
                  @supported.channel.types = value
                  break
                when 'CHANNELLEN' then
                  @supported.channel.length = parseInt(value)
                  break
                when 'IDCHAN' then
                  for val in value.split(',')
                    val = val.split(':')
                    @supported.channel.idlength[val[0]] = val[1]
                  break
                when 'KICKLEN' then
                  @supported.kicklength = value
                  break
                when 'MAXLIST' then
                  for val in value.split(',')
                    val = val.split(':')
                    @supported.maxlist[val[0]] = parseInt(val[1])
                  break
                when 'NICKLEN' then
                  @supported.nicklength = parseInt(value)
                  break
                when 'PREFIX' then
                  if match = value.match(/\((.*?)\)(.*)/)
                    match[1] = match[1].split('')
                    match[2] = match[2].split('')
                    while match[1].length
                      @modeForPrefix[match[2][0]] = match[1][0]
                      @supported.channel.modes.b += match[1][0]
                      @prefixForMode[match[1].shift()] = match[2].shift()
                  break
                when 'STATUSMSG' then break
                when 'TARGMAX' then
                  for val in value.split(',')
                    val = val.split(':')
                    val[1] = if not val[1] then 0 else parseInt(val[1])
                    @supported.maxtargets[val[0]] = val[1]
                  break
                when 'TOPICLEN' then
                  @supported.topiclength = parseInt(value)
                  break
          break
        when "rpl_luserclient" then
        when "rpl_luserop" then
        when "rpl_luserchannels" then
        when "rpl_luserme" then
        when "rpl_localusers" then
        when "rpl_globalusers" then
        when "rpl_statsconn" then
          # Random welcome crap, ignoring
          break
        when "err_nicknameinuse" then
          if ( typeof(self.opt.nickMod) == 'undefined' )
            self.opt.nickMod = 0;
          self.opt.nickMod++;
          self.send("NICK", self.opt.nick + self.opt.nickMod);
          self.nick = self.opt.nick + self.opt.nickMod;
          break;
        when "PING" then
          self.send("PONG", message.args[0]);
          self.emit('ping', message.args[0]);
          break;
        when "NOTICE" then
          var from = message.nick;
          var to   = message.args[0];
          if (!to) {
            to   = null;
          }
          var text = message.args[1];
          if (text[0] === '\1' && text.lastIndexOf('\1') > 0) {
            self._handleCTCP(from, to, text, 'notice');
            break;
          }
          self.emit('notice', from, to, text, message);

          if ( self.opt.debug && to == self.nick )
            util.log('GOT NOTICE from ' + (from?'"'+from+'"':'the server') + ': "' + text + '"');
          break;
        when "MODE" then
          if ( self.opt.debug )
            util.log("MODE:" + message.args[0] + " sets mode: " + message.args[1]);

          var channel = self.chanData(message.args[0]);
          if ( !channel ) break;
          var modeList = message.args[1].split('');
          var adding = true;
          var modeArgs = message.args.slice(2);
          modeList.forEach(function(mode) {
            if ( mode == '+' ) { adding = true; return; }
            if ( mode == '-' ) { adding = false; return; }
            if ( mode in self.prefixForMode ) {
              // channel user modes
              var user = modeArgs.shift();
              if ( adding ) {
                if ( channel.users[user].indexOf(self.prefixForMode[mode]) === -1 )
                  channel.users[user] += self.prefixForMode[mode];

                self.emit('+mode', message.args[0], message.nick, mode, user, message);
              }
              else {
                channel.users[user] = channel.users[user].replace(self.prefixForMode[mode], '');
                self.emit('-mode', message.args[0], message.nick, mode, user, message);
              }
            }
            else {
              var modeArg;
              // channel modes
              if ( mode.match(/^[bkl]$/) ) {
                modeArg = modeArgs.shift();
                if ( modeArg.length === 0 )
                  modeArg = undefined;
              }
              // TODO - deal nicely with channel modes that take args
              if ( adding ) {
                if ( channel.mode.indexOf(mode) === -1 )
                  channel.mode += mode;

                self.emit('+mode', message.args[0], message.nick, mode, modeArg, message);
              }
              else {
                channel.mode = channel.mode.replace(mode, '');
                self.emit('-mode', message.args[0], message.nick, mode, modeArg, message);
              }
            }
          });
          break;
        when "NICK" then
          if ( message.nick == self.nick )
            // the user just changed their own nick
            self.nick = message.args[0];

          if ( self.opt.debug )
            util.log("NICK: " + message.nick + " changes nick to " + message.args[0]);

          var channels = [];

          // TODO better way of finding what channels a user is in?
          for ( var channame in self.chans ) {
            var channel = self.chans[channame];
            if ( 'string' == typeof channel.users[message.nick] ) {
              channel.users[message.args[0]] = channel.users[message.nick];
              delete channel.users[message.nick];
              channels.push(channame);
            }
          }

          // old nick, new nick, channels
          self.emit('nick', message.nick, message.args[0], channels, message);
          break;
        when "rpl_motdstart" then
          self.motd = message.args[1] + "\n";
          break;
        when "rpl_motd" then
          self.motd += message.args[1] + "\n";
          break;
        when "rpl_endofmotd" then
        when "err_nomotd" then
          self.motd += message.args[1] + "\n";
          self.emit('motd', self.motd);
          break;
        when "rpl_namreply" then
          var channel = self.chanData(message.args[2]);
          var users = message.args[3].trim().split(/ +/);
          if ( channel ) {
            users.forEach(function (user) {
              var match = user.match(/^(.)(.*)$/);
              if ( match ) {
                if ( match[1] in self.modeForPrefix ) {
                  channel.users[match[2]] = match[1];
                }
                else {
                  channel.users[match[1] + match[2]] = '';
                }
              }
            });
          }
          break;
        when "rpl_endofnames" then
          var channel = self.chanData(message.args[1]);
          if ( channel ) {
            self.emit('names', message.args[1], channel.users);
            self.emit('names' + message.args[1], channel.users);
            self.send('MODE', message.args[1]);
          }
          break;
        when "rpl_topic" then
          var channel = self.chanData(message.args[1]);
          if ( channel ) {
            channel.topic = message.args[2];
          }
          break;
        when "rpl_away" then
          self._addWhoisData(message.args[1], 'away', message.args[2], true);
          break;
        when "rpl_whoisuser" then
          self._addWhoisData(message.args[1], 'user', message.args[2]);
          self._addWhoisData(message.args[1], 'host', message.args[3]);
          self._addWhoisData(message.args[1], 'realname', message.args[5]);
          break;
        when "rpl_whoisidle" then
          self._addWhoisData(message.args[1], 'idle', message.args[2]);
          break;
        when "rpl_whoischannels" then
          self._addWhoisData(message.args[1], 'channels', message.args[2].trim().split(/\s+/)); // TODO - clean this up?
          break;
        when "rpl_whoisserver" then
          self._addWhoisData(message.args[1], 'server', message.args[2]);
          self._addWhoisData(message.args[1], 'serverinfo', message.args[3]);
          break;
        when "rpl_whoisoperator" then
          self._addWhoisData(message.args[1], 'operator', message.args[2]);
          break;
        when "330" then # rpl_whoisaccount?
          self._addWhoisData(message.args[1], 'account', message.args[2]);
          self._addWhoisData(message.args[1], 'accountinfo', message.args[3]);
          break;
        when "rpl_endofwhois" then
          self.emit('whois', self._clearWhoisData(message.args[1]));
          break;
        when "rpl_liststart" then
          self.channellist = [];
          self.emit('channellist_start');
          break;
        when "rpl_list" then
          var channel = {
            name: message.args[1],
            users: message.args[2],
            topic: message.args[3],
          };
          self.emit('channellist_item', channel);
          self.channellist.push(channel);
          break;
        when "rpl_listend" then
          self.emit('channellist', self.channellist);
          break;
        when "333" then
          // TODO emit?
          var channel = self.chanData(message.args[1]);
          if ( channel ) {
            channel.topicBy = message.args[2];
            // channel, topic, nick
            self.emit('topic', message.args[1], channel.topic, channel.topicBy, message);
          }
          break;
        when "TOPIC" then
          // channel, topic, nick
          self.emit('topic', message.args[0], message.args[1], message.nick, message);

          var channel = self.chanData(message.args[0]);
          if ( channel ) {
            channel.topic = message.args[1];
            channel.topicBy = message.nick;
          }
          break;
        when "rpl_channelmodeis" then
          var channel = self.chanData(message.args[1]);
          if ( channel ) {
            channel.mode = message.args[2];
          }
          break;
        when "329" then
          var channel = self.chanData(message.args[1]);
          if ( channel ) {
            channel.created = message.args[2];
          }
          break;
        when "JOIN" then
          // channel, who
          if ( self.nick == message.nick ) {
            self.chanData(message.args[0], true);
          }
          else {
            var channel = self.chanData(message.args[0]);
            channel.users[message.nick] = '';
          }
          self.emit('join', message.args[0], message.nick, message);
          self.emit('join' + message.args[0], message.nick, message);
          if ( message.args[0] != message.args[0].toLowerCase() ) {
            self.emit('join' + message.args[0].toLowerCase(), message.nick, message);
          }
          break;
        when "PART" then
          // channel, who, reason
          self.emit('part', message.args[0], message.nick, message.args[1], message);
          self.emit('part' + message.args[0], message.nick, message.args[1], message);
          if ( message.args[0] != message.args[0].toLowerCase() ) {
            self.emit('part' + message.args[0].toLowerCase(), message.nick, message.args[1], message);
          }
          if ( self.nick == message.nick ) {
            var channel = self.chanData(message.args[0]);
            delete self.chans[channel.key];
          }
          else {
            var channel = self.chanData(message.args[0]);
            delete channel.users[message.nick];
          }
          break;
        when "KICK" then
          // channel, who, by, reason
          self.emit('kick', message.args[0], message.args[1], message.nick, message.args[2], message);
          self.emit('kick' + message.args[0], message.args[1], message.nick, message.args[2], message);
          if ( message.args[0] != message.args[0].toLowerCase() ) {
            self.emit('kick' + message.args[0].toLowerCase(), message.args[1], message.nick, message.args[2], message);
          }

          if ( self.nick == message.args[1] ) {
            var channel = self.chanData(message.args[0]);
            delete self.chans[channel.key];
          }
          else {
            var channel = self.chanData(message.args[0]);
            delete channel.users[message.args[1]];
          }
          break;
        when "KILL" then
          var nick = message.args[0];
          var channels = [];
          for ( var channel in self.chans ) {
            if ( self.chans[channel].users[nick])
              channels.push(channel);

            delete self.chans[channel].users[nick];
          }
          self.emit('kill', nick, message.args[1], channels, message);
          break;
        when "PRIVMSG" then
          var from = message.nick;
          var to   = message.args[0];
          var text = message.args[1];
          if (text[0] === '\1' && text.lastIndexOf('\1') > 0) {
            self._handleCTCP(from, to, text, 'privmsg');
            break;
          }
          self.emit('message', from, to, text, message);
          if ( self.supported.channel.types.indexOf(to.charAt(0)) !== -1 ) {
            self.emit('message#', from, to, text, message);
            self.emit('message' + to, from, text, message);
            if ( to != to.toLowerCase() ) {
              self.emit('message' + to.toLowerCase(), from, text, message);
            }
          }
          if ( to == self.nick ) self.emit('pm', from, text, message);

          if ( self.opt.debug && to == self.nick )
            util.log('GOT MESSAGE from ' + from + ': ' + text);
          break;
        when "INVITE" then
          var from = message.nick;
          var to   = message.args[0];
          var channel = message.args[1];
          self.emit('invite', channel, from, message);
          break;
        when "QUIT" then
          if ( self.opt.debug )
            util.log("QUIT: " + message.prefix + " " + message.args.join(" "));
          if ( self.nick == message.nick ) {
            // TODO handle?
            break;
          }
          // handle other people quitting

          var channels = [];

          // TODO better way of finding what channels a user is in?
          for ( var channame in self.chans ) {
            var channel = self.chans[channame];
            if ( 'string' == typeof channel.users[message.nick] ) {
              delete channel.users[message.nick];
              channels.push(channame);
            }
          }

          // who, reason, channels
          self.emit('quit', message.nick, message.args[0], channels, message);
          break;
        when "err_umodeunknownflag" then
          if ( self.opt.showErrors )
            util.log("\033[01;31mERROR: " + util.inspect(message) + "\033[0m");
          break;
        else
          if ( message.commandType == 'error' ) {
            self.emit('error', message);
            if ( self.opt.showErrors )
              util.log("\033[01;31mERROR: " + util.inspect(message) + "\033[0m");
          }
          else {
            if ( self.opt.debug )
              util.log("\033[01;31mUnhandled message: " + util.inspect(message) + "\033[0m");
          }
          break;
