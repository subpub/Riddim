function riddim.plugins.msgforward(bot)
	local compare_jid = require "util.jid".compare;
	local st_clone = require "util.stanza".clone;
	local forwards = bot.config.forwards or {};

	bot:hook("message", function(event)
		local message = event.stanza;
		local from = message.attr.from;
		local body = message:get_child("body");
		body = body and body:get_text();
		if not body then return end
		for jid, room in pairs(forwards) do
			if compare_jid(from, jid) and bot.rooms[room] then
				local out = st_clone(message);
				out.attr.to, out.attr.from, out.attr.type = nil, nil, "groupchat";
				bot.rooms[room]:send(out);
				return true;
			end
		end
	end);
end
