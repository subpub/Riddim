local storage_backends = {};
function riddim.plugins.factoids(bot)
	local factoids = {};
	local conf_backend = bot.config.factoid_backend;
	local backend;

	-- if backend == nil then forget everything on restart

	if conf_backend and storage_backends[conf_backend] then
		backend = storage_backends[conf_backend](bot, factoids);
	end

	bot:hook("unhandled-command", function(cmd)
		local name, param = cmd.command, cmd.param;
		local factoid = factoids[name];
		if factoid then
			return factoid;
		elseif param and #param > 4 and param:match("^is ") then
			factoids[name] = param:sub(4);
			return "I'll remember that.";
		end
	end);
	bot:hook("commands/forget", function(cmd)
		local name = cmd.param;
		local factoid = factoids[name];
		if factoid then
			factoids[name] = nil;
			if backend and backend.del then
				backend.del(name);
			end
			return ("Okay, I'll forget that %s is %s"):format(name, factoid);
		end
	end);
end

-- A simple file backend
function storage_backends.file(bot, factoids)
	local factoids_file = bot.config.factoids_file or "./factoids.txt";
	local function format_line(k, v)
		return ("%s=%s\n"):format(k, v)
	end
	local actions = {
		load = function()
			local fd = io.open(factoids_file, "r");
			if fd then
				for line in fd:lines() do
					local k, v = line:match("^(.+)=(.*)$");
					if k and v then
						factoids[k] = v;
					end
				end
				fd:close();
			end
		end,
		save = function()
			local fd = io.open(factoids_file, "w");
			if fd then
				for k,v in pairs(factoids) do
					fd:write(format_line(k, v));
				end
				fd:close();
			end
		end,
		add = function(k, v)
			local fd = io.open(factoids_file, "a");
			fd:write(format_line(k, v));
			fd:close();
		end,
	};
	function actions.del(...) actions.save(); end
	actions.load();
	setmetatable(factoids, {
		__newindex = function(t, k, v)
			v = v:gsub("\n"," ");
			rawset(t, k, v);
			actions.add(k, v);
		end,
	});
	return actions;
end

-- A variant of the above except serializing lua code
function storage_backends.lua(bot, factoids)
	local factoids_file = bot.config.factoids_file or "./factoids.dat";
	local function format_line(k, v)
		return ("_G[%q] = %q;\n"):format(k, v);
	end
	local actions = {
		load = function()
			local chunk, err = loadfile(factoids_file);
			if chunk then
				local old_mt = getmetatable(factoids);
				setmetatable(factoids, {
					__newindex = function (...) rawset(...); print(...) end
				});
				setfenv(chunk, {_G = factoids} );
				chunk();
				setmetatable(factoids, old_mt);
			else
				print(err);
			end
		end,
		save = function()
			local fd, err = io.open(factoids_file, "w");
			if err then print(err) end
			if fd then
				for k,v in pairs(factoids) do
					fd:write(format_line(k, v));
				end
				fd:close();
			end
		end,
		add = function(k,v)
			local fd, err = io.open(factoids_file, "a");
			if err then print(err) end
			if fd then
				fd:write(format_line(k, v));
				fd:close();
			end
		end,
		del = function(k)
			local fd, err = io.open(factoids_file, "a");
			if err then print(err) end
			if fd then
				fd:write(("_G[%q] = nil;\n"):format(k));
				fd:close();
			end
		end,
	}
	actions.load();
	setmetatable(factoids, {
		__newindex = function(t, k, v)
			print("__newindex", t, k, v);
			rawset(t, k, v);
			actions.add(k, v);
		end,
	});
	return actions;
end

-- Yet another variant, using util.serialization
function storage_backends.serialize(bot, factoids)
	local serialize   = require "util.serialization".serialize;
	local deserialize = require "util.serialization".deserialize;
	local factoids_file = bot.config.factoids_file or "./factoids.dat";
	local actions = {
		load = function()
			local fd = io.open(factoids_file, "r");
			if fd then
				local old_mt = getmetatable(factoids);
				setmetatable(factoids, {});
				factoids = deserialize(fd:read("*a"));
				setmetatable(factoids, old_mt);
				df:close();
			end
		end,
		save = function()
			local fd, err = io.open(factoids_file, "w");
			if err then print(err) end
			if fd then
				fd:write(serialize(factoids));
				fd:close();
			end
		end,
	}
	function actions.add(...) actions.save(); end
	function actions.del(...) actions.save(); end
	actions.load();
	setmetatable(factoids, {
		__newindex = function(t, k, v)
			print("__newindex", t, k, v);
			rawset(t, k, v);
			actions.add(k, v);
		end,
	});
	return actions;
end

-- A backend using XEP 49 storage
function storage_backends.iq_private(bot, factoids)
	bot.stream:add_plugin("private");
	local factoids_node = "factoids";
	local factoids_xmlns = "http://code.zash.se/riddim/plugins/factoids";
	local actions = {
		load = function()
			bot.stream:private_get(factoids_node, factoids_xmlns, function (storage)
				if storage then
					local old_mt = getmetatable(factoids);
					setmetatable(factoids, {
						__newindex = function (...) rawset(...); print(...) end
					});
					for factoid in storage:children() do
						factoids[factoid.attr.name or "something-invalid"] = factoid:get_text();
					end
					setmetatable(factoids, old_mt);
				end
			end);
		end,
		save = function()
			local st = verse.stanza(factoids_node, { xmlns = factoids_xmlns });
			for name, text in pairs(factoids) do
				st:tag("factoid", { name = name }):text(text):up();
			end
			bot.stream:private_set(factoids_node, factoids_xmlns, st);
		end,
	}
	function actions.add(...) actions.save(); end
	function actions.del(...) actions.save(); end
	bot:hook("started", function()
		actions.load();
		setmetatable(factoids, {
			__newindex = function(t, k, v)
				print("__newindex", t, k, v);
				rawset(t, k, v);
				actions.add(k, v);
			end,
		});
	end);
	return actions;
end
