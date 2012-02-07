function riddim.plugins.urltitle(bot)
	require "net.httpclient_listener";
	local http = require "net.http";

	local function handler(message)
		local url = message.body and message.body:match("https?://%S+");
		if url then
			http.request(url, nil, function (data, code)
				if code ~= 200 then return end
				local title = data:match("<title[^>]*>([^<]+)");

				if title then
					title = title:gsub("\n", "");
					if message.room then
						message.room:send_message(title)
					else
						message:reply(title);
					end
				end
			end);
		end
	end
	bot:hook("message", handler);
	bot:hook("groupchat/joined", function(room)
		room:hook("message", handler)
	end);
end
