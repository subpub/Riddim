function riddim.plugins.msgforward(bot)
	local compare_jid = require "util.jid".compare;
	local forwards = bot.config.forwards or {};
	bot:hook("message", function(event)
		local message = event.stanza;
		local from = message.attr.from;
		local body = message:get_child("body");
		body = body and body:get_text();
		if not body then return end
		for jid, room in pairs(forwards) do
			if compare_jid(from, jid) and bot.rooms[room] then
				bot.rooms[room]:send_message(body);
				return true;
			end
		end
	end);
end
