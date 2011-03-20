-- simple_commands.lua



local st = require 'util.stanza'

function riddim.plugins.simple_commands(bot)
   -- reply to message (but don't prepend the sender's nick like groupchat's
   -- event:reply does)
   local function bare_reply(command, reply)
      if command.stanza.attr.type == 'groupchat' then
	 local r = st.reply(command.stanza)
	 local room_jid = jid.bare(command.sender.jid);
	 if bot.rooms[room_jid] then
	    bot.rooms[room_jid]:send(r:tag("body"):text(reply));
	 end
      else
	 return command:reply(reply);
      end
   end

   local function exec(command)
      local reply = bot.config.simple_commands[command.command]
      if type(reply) == 'table' then
	 reply = reply[math.random(#reply)]
      end
      if type(reply) == 'string' then
	 if reply:match('%%s') then
	    if command.param then
	       bare_reply(command, reply:format(command.param))
	    end
	 else
	    bare_reply(command, reply)
	 end
      elseif type(reply) == 'function' then
	 bare_reply(command, reply(command.param))
      end
   end

   for k,v in pairs(bot.config.simple_commands) do
      bot:hook('commands/'..k, exec)
   end
end

-- end of simple_commands.lua
