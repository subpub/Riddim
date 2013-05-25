local st = require "util.stanza";
local xmlns_muc = "http://jabber.org/protocol/muc";

function riddim.plugins.groupchat(bot)
	bot.stream:add_plugin("groupchat")
	bot.rooms = bot.stream.rooms;

	bot:hook("started", function ()
		for k, v in pairs(bot.config.autojoin or {}) do
			if type(k) == "number" then
				bot:join_room(v);
			elseif type(k) == "string" then
				if type(v) == "string" then
					bot:join_room(k, v);
				end
			end
		end
	end);
	
	-- Re-broadcast groupchat event on the bot
	local reflect_events = { "groupchat/joining"; "groupchat/joined"; "groupchat/leaving"; "groupchat/left" };
	for i = 1,#reflect_events do
		bot.stream:hook(reflect_events[i], function(room, ...)
			room.bot = bot;
			bot:event(reflect_events[i], room, ...)
		end);
	end

	function bot:join_room(room_jid, nick)
		nick = nick or bot.config.nick or ("bot"..math.random(10000,99999));
		local room = bot.stream:join_room(room_jid, nick)
		room.bot = bot;
		room:hook("message", function(event)
			if event.nick == room.nick then
				return true;
			end
		end, 1000);
		room:hook("message", function(event)
			local stanza = event.stanza;
			local replied;
			local r = st.reply(stanza);
			if stanza.attr.type == "groupchat" then
				r.attr.type = stanza.attr.type;
				r.attr.to = jid.bare(stanza.attr.to);
			end
			function event:reply(reply)
				if not reply then reply = "Nothing to say to you"; end
				if replied then return false; end
				replied = true;
				if reply:sub(1,4) ~= "/me " and event.sender and r.attr.type == "groupchat" then
					reply = (event.reply_to or event.sender.nick)..": "..reply;
				end
				room:send(r:tag("body"):text(reply));
			end
		end, 500);
		return room;
	end

	bot.stream:hook("pre-groupchat/joining", function(presence)
		local muc_x = presence:get_child("x", xmlns_muc);
		if muc_x then
			muc_x:tag("history",{maxstanzas = 0});
		end
	end);
end
