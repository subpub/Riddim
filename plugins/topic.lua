function riddim.plugins.topic(bot)
	bot:hook("commands/topic", function(cmd)
		local room = cmd.room;
		if not room then return "This isn't a room!"; end
		if not cmd.param then return room.subject or "No topic here"; end
		room:set_subject(cmd.param);
	end);

	bot:hook("commands/addtopic", function(cmd)
		local room = cmd.room;
		if not room then return "This isn't a room!"; end
		if not cmd.param then return "What do you want me do add?"; end
		room:set_subject((#room.subject>0 and room.subject .. cmd.param) or cmd.param)
	end);
end
