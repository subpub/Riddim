local st = require "util.stanza";

function riddim.plugins.uptime(bot)
	bot.stream:add_plugin("uptime");
	bot.stream.uptime:set{
		starttime = os.time();
	};

	bot:hook("commands/uptime", function (command)
		local who, param = bot.stream.jid, command.param;
		local reply_prefix = "I have been running for ";
		if param then
			if command.room and command.room.occupants[param] then
				who = command.room.occupants[param].jid;
				reply_prefix = param.." has been idle for ";
			elseif command.room and command.room.occupants[param:gsub("%s$", "")] then
				who = command.room.occupants[param:gsub("%s$", "")].jid;
				reply_prefix = param.." has been idle for ";
			else
				who = param;
				reply_prefix = param.." has been running for ";
			end
		end

		bot.stream:query_uptime(who, function (reply)
			if not reply.error then
				command:reply(reply_prefix..convert_time(reply.seconds));
			else
				local type, condition, text = reply.type, reply.condition, reply.text;
				local r = "There was an error requesting "..param.."'s version";
				if condition == "service-unavailable" then
					r = param.." doesn't reply to uptime/last activity requests";
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

	function convert_time(value)
			local t = value;
			local seconds = t%60;
			t = (t - seconds)/60;
			local minutes = t%60;
			t = (t - minutes)/60;
			local hours = t%24;
			t = (t - hours)/24;
			local days = t;
			return string.format("%d day%s, %d hour%s and %d minute%s",
				days, (days ~= 1 and "s") or "", hours, (hours ~= 1 and "s") or "",
				minutes, (minutes ~= 1 and "s") or "");
	end
end
