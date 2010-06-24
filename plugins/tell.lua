local st = require "util.stanza";
local tellings = {};

function riddim.plugins.tell(bot)
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

		if tellings[nick] == nil then
			tellings[nick] = {};
		end
		tellings[nick][#tellings[nick] + 1] = {from=command.sender.nick, msg=msg};
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
		if not tellings[nick] then
			return "I have no messages for "..nick;
		end

		-- no message id and message for that user
		if id == nil then
			local response = "I am supposed to relay the following message to "..nick.." :";
			for index,msg in ipairs(tellings[nick]) do
				response = response .. "\n#"..index.." : "..msg.msg;
			end
			return response;
		end

		-- check the message id is valid
		local number = #tellings[nick];
		id = tonumber(id)
		if id == nil or id < 1 or id > number then
			return "I need a valid message #id .. sigh !!\n"..nick.." has "..number.." message(s)";
		end

		if tellings[nick][id].from ~= command.sender.nick then
			return "you never said that, "..tellings[nick][id].from.." did !";
		end

		-- remove the message
		if number > 1 then
			tellings[nick][id] = tellings[nick][number];
			tellings[nick][number] = nil;
			return "what was I supposed to tell "..nick.." again ?";
		else
			tellings[nick] = nil;
			return "who is "..nick.." anyway ?";
		end
	end);

	bot:hook("groupchat/joined", function (room)
		room:hook("occupant-joined", function (occupant)
			if(tellings[occupant.nick] ~= nil) then
				for _,msg in ipairs(tellings[occupant.nick]) do
					room:send_message(occupant.nick .. ": Welcome back! " .. msg.from .. " told me, to tell you, \"" .. msg.msg .. "\".");
				end
				tellings[occupant.nick] = nil;
			end
		end);
	end);
end
