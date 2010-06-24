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

