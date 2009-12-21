
function riddim.plugins.ping(bot)
	bot.stream:add_plugin("ping");
	bot:hook("commands/ping", function (command)
			local jid = command.param;
			if jid then
				bot.stream:ping(jid, function (time)
					command:reply(string.format("Pong from %s in %0.3f seconds", jid, time));
				end);
				return true;
			end
			return "pong";
		end);
end
