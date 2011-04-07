local st = require "util.stanza";

-- set allow_add_bookmarks = true; in config to enable the bookmark command

function riddim.plugins.bookmarks(bot)
	local my_bookmarks = {};

	bot.stream:add_plugin("private");

	local function get_bookmarks(callback) 
		bot.stream:private_get("storage", "storage:bookmarks", function(storage)
			if not storage then
				storage = st.tag("storage", { xmlns = "storage:bookmarks" });
			end
			if callback and type(callback) == "function" then
				callback(storage);
			end
		end);
	end

	local function add_bookmark(bookmark, callback)
		-- TODO Check if a room is bookmarked already
		if not bookmark or type(bookmark) ~= "table" or not bookmark.jid then return end
		if not bookmark.name then
			bookmark.name = jid.split(bookmark.jid);
		end
		local nick = bot.config.nick;
		if bookmark.nick then
			nick = bookmark.nick;
			bookmark.nick = nil;
		end
		get_bookmarks(function(storage)
			storage:tag("conference", bookmark)
				:tag("nick"):text(nick):up()
			:up();
			bot.stream:private_set("storage", "storage:bookmarks", storage, callback);
		end);
	end

	local function join_bookmarked_rooms()
		get_bookmarks(function(storage)
			for i, room in ipairs(storage) do
				if room.name == "conference" and room.attr.jid then
					my_bookmarks[room.attr.jid] = true; -- to know which rooms are bookmarked
					if room.attr.autojoin == "true" or room.attr.autojoin == "1" then
						nick = room:get_child("nick");
						nick = nick and nick[1] or nil;
						bot:join_room(room.attr.jid, nick);
					end
					-- TODO Passwords
					-- Maybe get the hook in before the groupchat is loaded
					-- and add to the bot.config.autojoin variable?
				end
			end
		end);
	end

	bot:hook("started", join_bookmarked_rooms);

	if bot.config.allow_add_bookmarks then
		bot:hook("commands/bookmark", function(command)
			local room = command.param and jid.bare(command.param) or command.room.jid;
			if my_bookmarks[room] then return "Already bookmarked" end
			my_bookmarks[room] = true;
				
			add_bookmark({ jid = room, autojoin = "true" }, function() command:reply("Bookmarked " .. room) end);
		end);
	end

end
