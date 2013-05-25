function riddim.plugins.commands(bot)
	local command_pattern = "^%"..(bot.config.command_prefix or "@").."([%a%-%_%d]+)(%s?)(.*)$";

	local direct_address_pattern = false;
	if bot.config.nick then
		direct_address_pattern = "^"..bot.config.nick.."[,: ]+([%a%-%_%d]+)(%s?)(.*)";
	end

	local function process_command(event)
		local body = event.body;
		if not body then return; end
		if event.delay then return; end -- Don't process old messages from groupchat

		local command, hasparam, param = body:match(command_pattern);
	
		if not command and direct_address_pattern then
			command, hasparam, param = body:match(direct_address_pattern);
		end
	
		if not command then
			command, hasparam, param = body:match("%[([%a%-%_%d]+)(%s?)(.*)%]");
			if event.room then
				local direct_to = body:match"^(.-)[,:]"
				if event.room.occupants[direct_to] then
					event.reply_to = direct_to
				end
			end
		end
		
		if hasparam ~= " " then param = nil; end
	
		if command then
			local command_event = {
				command = command,
				param = param,
				sender = event.sender,
				stanza = event.stanza,
				reply = event.reply,
				room = event.room, -- groupchat support
			};
			local ret = bot:event("commands/"..command, command_event);
			if ret == nil then
				ret = bot:event("unhandled-command", command_event);
			end
			if type(ret) == "string" then
				event:reply(ret);
			end
			return ret;
		end
	end
	
	-- Hook messages sent to bot, fire a command event on the bot
	bot:hook("message", process_command);
	
	-- Support groupchat plugin: Hook messages from rooms that the bot joins
	bot:hook("groupchat/joining", function (room)
		room:hook("message", process_command);
	end);
end
