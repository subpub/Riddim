require "util.xstanza"

function riddim.plugins.commands(bot)
	local function handle_message(message)
		-- Parse message body
	end
	
	local command_pattern = "^%"..(bot.config.command_prefix or "@").."([%a%-%_%d]+)(%s?)(.*)$";

	local function process_command(event)
		local body, sender = event.body, event.sender;
		if not body then return; end
		if event.delay then return; end -- Don't process old messages

		local command, hasparam, param = body:match(command_pattern);
	
		if not command then
			command, hasparam, param = body:match("%[([%a%-%_%d]+)(%s?)(.*)%]");
		end
		
		if hasparam ~= " " then param = nil; end
	
		if command then
			local command_event = {
						command = command,
						param = param,
						sender = sender,
						stanza = event.stanza,
						reply = event.reply,
						room = event.room,
					};
			local ret = bot:event("commands/"..command, command_event);
			if type(ret) == "string" then
				event:reply(ret);
			end
			return ret;
		end
	end
	
	-- Hook messages to bot and from rooms, fire a command event on the bot
	bot:hook("message", process_command);
	
	bot:hook("groupchat/joining", function (room)
		room:hook("message", process_command);
	end);
end
