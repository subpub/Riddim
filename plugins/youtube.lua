-- Copyright (C) 2010 Thilo Cestonaro
-- 
-- This project is MIT/X11 licensed.
--
require("net.httpclient_listener");
local http = require("net.http");
local st = require("util.stanza");
local tostring = tostring;

function riddim.plugins.youtube(bot)
	local youtubelink_pattern = "http:%/%/www.youtube.com%/watch%?v=([%a%-%_%d]+)";

	local function bare_reply(event, reply)
		if event.stanza.attr.type == 'groupchat' then
			local r = st.reply(event.stanza)
			local room_jid = jid.bare(event.sender.jid);
			if bot.rooms[room_jid] then
				bot.rooms[room_jid]:send(r:tag("body"):text(reply));
			end
		else
			return event:reply(reply);
		end
	end

	local function findYoutubeLink(event)
		local body = event.body;
		if not body then return; end
		if event.delay then return; end -- Don't process old messages from groupchat

		local videoId = body:match(youtubelink_pattern);

		if videoId then
			print("VideoID: "..tostring(videoId));
			http.request("http://gdata.youtube.com/feeds/api/videos/"..tostring(videoId).."?v=2", nil, function (data, code, request)
				print("returned code: "..tostring(code));
				print("-------------------------------------------------------------------------------------------");
				print("returned data: "..tostring(data));
				print("-------------------------------------------------------------------------------------------");
				if code ~= 200 then
					if code > 0 then
						event:reply("Received HTTP "..code.." error (video gone?)");
					else
						event:reply("Unable to fetch the XEP list from xmpp.org: "..data:gsub("%-", " "));
					end
					return;
				end
				bare_reply(event, "Title: " .. data:match("<title>(.-)</title>"))
			end);
		end
	end

	bot:hook("message", findYoutubeLink);
	bot:hook("groupchat/joining", function (room)
		room:hook("message", findYoutubeLink);
	end);
end

