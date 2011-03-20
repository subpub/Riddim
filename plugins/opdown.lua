local jid_bare = require "util.jid".bare;

function riddim.plugins.opdown(bot)
	local admin = bot.config.admin;

	-- To allow anyone other than the admin to use a command,
	-- simply add them to the table, like
	-- opdown_map = {
	--   op = { role = "moderator", "operator@host" }, -- operator is allowed to use !op
	--   "admin@host" -- allowed to use all commands
	-- }
	-- also, bot.config.admin is allowed to do anything

	local command_map = bot.config.opdown_map or {
		owner = { affiliation =       "owner" };
		admin = { affiliation =       "admin" };
		op    = { role        =   "moderator" };
		member= { affiliation =      "member" };
		down  = { role        = "participant",
		          affiliation =        "none" };
		--ban   = { affiliation =     "outcast" };
		--kick  = { role        =        "none" };
	}

	function opdown(command)
		if not command.room then
			return "This command is only available in groupchats.";
		end

		local what = command_map[command.command];
		if not what then return end
		local room = command.room;
		local who = command.param or command.sender.nick;
		local commander = command.sender;
		local actor = jid_bare(command.sender.real_jid);

		if not actor then
			return "I don't know who you really are?";
		end

		if actor ~= admin then
			local allow = false;
			for i = 1,#what do
				if what[i] == actor then
					allow = true;
					break;
				end
			end
			if not allow then
				for i = 1,#command_map do
					if command_map[i] == actor then
						allow = true;
						break;
					end
				end
			end
			if not allow then
				return "I can't let you do that!";
			end
		end

		if command.room.occupants[who] then
			if what.role then
				command.room:set_role(who, what.role, "As commanded");
			end
			if what.affiliation then
				command.room:set_affiliation(who, what.affiliation, "As commanded");
			end
		end
	end

	for k in pairs(command_map) do
		bot:hook("commands/" .. k, opdown);
	end
end

