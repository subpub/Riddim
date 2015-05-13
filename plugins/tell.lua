local st = require "util.stanza";
local memory_ns = "http://code.matthewwild.co.uk/riddim/plugins/tell"
local serializer = false;
local tellings = {};

function riddim.plugins.tell(bot)
	if bot.config.remember_tells then
		bot.stream:add_plugin("private");
		serializer = require "json"; --TODO other serializer?
	end

	local sameroom = bot.config.tell_in_same_room;

	local function remember()
		if serializer then
			bot.stream:private_set("tellings", memory_ns, serializer.encode(tellings), function () end);
		end
	end

	bot:hook("commands/tell", function (command)
		if not command.room then
			return "This command is only available in groupchats.";
		end
		if not command.param then
			return "If you want me to tell someone something then do so";
		end

		local s, e = command.param:find(" ");

		if not s then
			return "if you have nothing to say to "..command.param..", then leave me alone, please";
		end

		local nick = command.param:sub(0, s - 1);
		local msg = command.param:sub(s + 1);

		if nick == command.sender.nick then
			return "Tell yourself.";
		end

		for tmp,_ in pairs(command.room.occupants) do
			if tmp == nick then
				return "" .. nick .. " is currently online!";
			end
		end

		local nick_id = sameroom and command.room.jid .. "/" .. nick or nick;

		if tellings[nick_id] == nil then
			tellings[nick_id] = {};
		end
		tellings[nick_id][#tellings[nick_id] + 1] = {from=command.sender.nick, msg=msg};
		remember();
		return "Ok!";
	end);

	bot:hook("commands/untell", function (command)
		if not command.room then
			return "This command is only available in groupchats.";
		end
		if not command.param then
			return "If you changed your mind tell me for who";
		end

		local s, e = command.param:find(" ");
		local nick;
		local id;

		-- parameter parsing
		if not s then
			nick = command.param;
			id = nil;
		else
			nick = command.param:sub(0, s - 1);
			id = command.param:sub(s + 1);
		end

		-- no message for that user
		local nick_id = sameroom and command.room.jid .. "/" .. nick or nick;
		if not tellings[nick_id] then
			return "I have no messages for "..nick;
		end

		-- no message id and message for that user
		if id == nil then
			local response = "I am supposed to relay the following message to "..nick.." :";
			for index,msg in ipairs(tellings[nick_id]) do
				response = response .. "\n#"..index.." : "..msg.msg;
			end
			return response;
		end

		-- check the message id is valid
		local number = #tellings[nick_id];
		id = tonumber(id)
		if id == nil or id < 1 or id > number then
			return "I need a valid message #id .. sigh !!\n"..nick.." has "..number.." message(s)";
		end

		if tellings[nick_id][id].from ~= command.sender.nick then
			return "you never said that, "..tellings[nick_id][id].from.." did !";
		end

		-- remove the message
		if number > 1 then
			tellings[nick_id][id] = tellings[nick_id][number];
			tellings[nick_id][number] = nil;
			remember();
			return "what was I supposed to tell "..nick.." again ?";
		else
			tellings[nick_id] = nil;
			remember();
			return "who is "..nick.." anyway ?";
		end
	end);

	if serializer then
		bot:hook("started", function() -- restore memory
			bot.stream:private_get("tellings", memory_ns, function (what)
				if what then
					local data = tostring(what:get_text());
					if data and #data > 0 then
						tellings = serializer.decode(data);
					end
				end
			end);
		end);
	end

	bot:hook("groupchat/joined", function (room)
		room:hook("occupant-joined", function (occupant)
			local nick_id = sameroom and room.jid .. "/" .. occupant.nick or occupant.nick;
			if(tellings[nick_id] ~= nil) then
				for _,msg in ipairs(tellings[nick_id]) do
					room:send_message(occupant.nick .. ": Welcome back! " .. msg.from .. " told me to tell you:\n" .. msg.msg);
				end
				tellings[nick_id] = nil;
				remember();
			end
		end);
	end);
end
