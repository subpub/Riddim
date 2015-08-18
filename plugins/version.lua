local st = require "util.stanza";

local xmlns_version = "jabber:iq:version";

local friendly_errors = {
	["service-unavailable"] = " doesn't reply to version requests";
	["feature-not-implemented"] = " doesn't support version requests";
	["remote-server-not-found"] = " can't be reached via XMPP";
}

function riddim.plugins.version(bot)
	bot.stream:add_plugin("version");
	bot.stream.version:set{
		name = bot.config.bot_name or "Riddim";
		version = bot.config.bot_version or "alpha";
		platform = bot.config.bot_platform or _VERSION;
	};

	bot:add_plugin("resolvejid");
	bot:hook("commands/version", function (command)
		local who, param = bot.stream.jid, command.param;
		if param then
			who = bot:resolvejid(param, command.room);
		end
		
		bot.stream:query_version(who, function (reply)
			if not reply.error then
				local saywho = (who == command.sender.jid and "You are") or (param and param.." is" or "I am");
				local isrunning = saywho.." running "..(reply.name or "something");
				if reply.version then
					isrunning = isrunning .." version "..reply.version;
				end
				if reply.platform then
					isrunning = isrunning .." on "..reply.platform;
				end
				command:reply(isrunning);
			else
				local type, condition, text = reply.type, reply.condition, reply.text;
				local r = "There was an error requesting "..param.."'s version";
				local friendly_error = friendly_errors[condition];
				if friendly_error then
					r = r .. friendly_error;
				elseif condition and not text then
					r = r..": "..(condition):gsub("%-", "  ");
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
