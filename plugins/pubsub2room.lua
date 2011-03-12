--[[ pubsub2room
relays pubsub broadcasts to rooms

example conf:
pubsub2room = {
	["pubsub.prosody.im#commits"] = {
		room = "prosody@conference.prosody.im";
		template = "${author.name} committed: ${title}";
	};
};
--]]

local st = require "util.stanza";

-- FIXME Should this really be here?
local extractor_mt = {
	__index = function (t, k)
		local n;
		if k:match("^data%.") then
			k = k:gsub("^data.", "");
			n = t.data;
		else
			n = t.stanza;
		end
		for x in k:gmatch("[^.]+") do
			n = n:get_child(x);
			if not n then return end
		end
		return n[1];
	end
};

local function new_extractor(stanza, data)
	return stanza and setmetatable({ stanza = stanza, data = data }, extractor_mt) or nil;
end

function riddim.plugins.pubsub2room(bot)
	local bare_jid = require "util.jid".bare;
	bot:add_plugin("pubsub");

	local config = bot.config.pubsub2room;
	bot:hook("pubsub/event", function(event)
		local conf = config[event.from .. "#" .. event.node];
		local room = bot.rooms[conf.room];
		local data = st.stanza(""):tag("id"):text(event.item.attr.id);
		local entry = event.item and new_extractor(event.item.tags[1], data)

		if not conf or not entry or not room then return end
		local message = conf.template:gsub("%${([^}]+)}", entry);
		room:send_message(message);
	end);

	-- FIXME When to unsubscribe?
	bot:hook("started", function()
		local jid = bare_jid(bot.stream.jid);
		for hostnode in pairs(config) do
			local host, node = hostnode:match("^([^#]+)#(.*)");
			bot.pubsub:subscribe(host, node, jid, print);
		end
	end);
end
