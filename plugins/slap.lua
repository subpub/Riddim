-- slap.lua

local st = require 'util.stanza'

function riddim.plugins.slap(bot)
   if type(bot.config.weapons) ~= 'table' then
      -- start off with something to slap people with
      bot.config.weapons = {'large trout'}
   end

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

   -- slap someone
   local function slap(command)
      local who, weapon
      if command.param then
	 who = command.param
      else
	 -- slap the sender if they don't specify a target
	 if bot.rooms[jid.bare(command.sender.jid)] then
	    who = select(3, jid.split(command.sender.jid))
	 else
	    who = (jid.split(command.sender.jid))
	 end
      end
      weapon = bot.config.weapons[math.random(#bot.config.weapons)]
      bare_reply(command, string.format('/me slaps %s with %s', who, weapon))
   end

   -- pick up a weapon for slapping
   local function weapon(command)
      if command.param then
	 if command.param:lower() == 'excalibur' then
	    command:reply 'Listen -- strange women lying in ponds distributing swords is no basis for a system of government.  Supreme executive power derives from a mandate from the masses, not from some farcical aquatic ceremony.'
	 elseif command.param:lower() == 'paper' then
	    bare_reply(command, '"Reverse primary thrust, Marvin." That\'s what they say to me. "Open airlock number 3, Marvin." "Marvin, can you pick up that piece of paper?" Here I am, brain the size of a planet, and they ask me to pick up a piece of paper.')
	 else
	    table.insert(bot.config.weapons, command.param)
	    bare_reply(command, '/me picks up '..command.param)
	 end
      else
	 command:reply 'Tell me what weapon to pick up'
      end
   end

   -- drop a weapon
   local function drop(command)
      if command.param then
	 local found
	 for i,v in ipairs(bot.config.weapons) do
	    local weapons = bot.config.weapons
	    if v == command.param then
	       if #weapons == 1 then
		  bare_reply(command, '/me refuses to drop his last weapon')
	       else
		  weapons[i] = weapons[#weapons]
		  table.remove(weapons)
		  found = true
	       end
	       break
	    end
	 end
	 if found then
	    bare_reply(command, '/me drops '..command.param)
	 else
	    bare_reply(command, "/me doesn't have "..command.param)
	 end
      else
	 command:reply 'Tell me what to drop'
      end
   end

   bot:hook('commands/slap', slap)
   bot:hook('commands/weapon', weapon)
   bot:hook('commands/drop', drop)
end

-- end of slap.lua
