local st = require "util.stanza";

local xmlns_version = "jabber:iq:version";

function riddim.plugins.version(bot)
	bot.stream:add_plugin("version");
	bot.stream.version:set{
		name = bot.config.bot_name or "Riddim";
		version = bot.config.bot_version or "alpha";
		platform = bot.config.bot_platform or _VERSION;
	};

	bot:hook("commands/version", function (command)
		local who, param = bot.stream.jid, command.param;
		if param then
			if command.room and command.room.occupants[param] then
				who = command.room.occupants[param].jid;
			elseif command.room and command.room.occupants[param:gsub("%s$", "")] then
				who = command.room.occupants[param:gsub("%s$", "")].jid;
			else
				who = param;
			end
		end
		
		bot.stream:query_version(who, function (reply)
			if not reply.error then
				local saywho = (who == command.sender.jid and "You are") or (param and param.." is" or "I am");
				command:reply(saywho.." running "..(reply.name or "something")
					.." version "..(reply.version or "unknown")
					.." on "..(reply.platform or "an unknown platform"));
			else
				local type, condition, text = reply.type, reply.condition, reply.text;
				local r = "There was an error requesting "..param.."'s version";
				if condition == "service-unavailable" then
					r = param.." doesn't reply to version requests";
				elseif condition == "feature-not-implemented" then
					r = param.." doesn't support feature requests";
				elseif condition == "remote-server-not-found" then
					r = param.." can't be reached via XMPP";
				elseif condition and not text then
					r = r..": "..condition;
				end
				if text then
					r = r .. " ("..text..")";
				end
				command:reply(r);
			end
		end);
		return true;
	end);	
end
