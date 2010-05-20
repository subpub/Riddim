local st = require "util.stanza";
local tellings = {};

function riddim.plugins.tell(bot)
	bot:hook("commands/tell", function (command)
		if command.room then
			local s, e = command.param:find(" ");
			local nick = command.param:sub(0, s - 1);
			local msg = command.param:sub(s + 1);
			local found = false;

			for tmp,_ in pairs(command.room.occupants) do
				if tmp == nick then
					found = true;
					break;
				end
			end

			if not found then
				if(tellings[nick] == nil) then
					tellings[nick] = {};
				end
				tellings[nick][#tellings[nick] + 1] = {from=command.sender.nick, msg=msg};
				return "Ok! Will tell " .. nick .. " what you have said!";
			else
				if nick == command.sender.nick then
					return "Are you going crazy!? You are " .. nick .. "!";
				else
					return "Aehm?! ... " .. nick .. " is currently online!";
				end
			end
		else
			return "Sorry, but this command only makes sense if you execute it in a groupchat.";
		end
	end);

	bot:hook("groupchat/joined", function (room)
		room:hook("occupant-joined", function (occupant)
			if(tellings[occupant.nick] ~= nil) then
				for _,msg in ipairs(tellings[occupant.nick]) do
					room:send_message(occupant.nick .. ": Welcome back! " .. msg.from .. " told me, to tell you, \"" .. msg.msg .. "\".");
				end
			end
		end);
	end);
end

