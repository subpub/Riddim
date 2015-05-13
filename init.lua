local verse = require "verse";
local st = require "util.stanza";

module("riddim", package.seeall);
plugins = {};

local riddim_mt = {};
riddim_mt.__index = riddim_mt;

function new(stream, config)
	if not stream then
		error("riddim.new(): Verse stream required as first parameter", 2);
	end
	return setmetatable({ stream = stream, config = config or {}, plugins = {} }, riddim_mt);
end

-- self.conn is ready for stanzas
function riddim_mt:start()
	self.stream:hook("stanza", function (stanza)
		local body = stanza:get_child("body");
		local event = {
			sender = { jid = stanza.attr.from };
			body = (body and body:get_text()) or nil;
			stanza = stanza;
		};
		if stanza.name == "message" then
			local replied;
			local bot = self;
			function event:reply(reply)
				if replied then return false; end
				replied = true;
				return bot:send_message(stanza.attr.from, stanza.attr.type, reply);
			end
		end
		local ret;
		if stanza.name == "iq" and (stanza.attr.type == "get" or stanza.attr.type == "set") then
			local xmlns = stanza.tags[1] and stanza.tags[1].attr.xmlns;
			if xmlns then
				event.xmlns = xmlns;
				ret = self:event("iq/"..xmlns, event);
			end
		end
		if not ret then
			ret = self:event(stanza.name, event);
		end
		if ret and type(ret) == "table" and ret.name then
			self:send(ret);
		end
		return ret;
	end, 1);
	self:event("started");
end

function riddim_mt:send(s)
	return self.stream:send(s);
end

function riddim_mt:send_iq(s, callback, errback)
	return self.stream:send_iq(s, callback, errback);
end

function riddim_mt:event(name, ...)
	return self.stream:event("bot/"..name, ...);
end
	
function riddim_mt:hook(name, ...)
	return self.stream:hook("bot/"..name, ...);
end

function riddim_mt:send_message(to, type, text)
	self:send(st.message({ to = to, type = type }):tag("body"):text(text));
end

function riddim_mt:send_presence(to, type)
	self:send(st.presence({ to = to, type = type }));
end

function riddim_mt:add_plugin(name)
	if not self.plugins[name] then
		self.plugins[name] = require("riddim.plugins."..name);
		return riddim.plugins[name](self);
	end
end
	
-- Built-in bot starter
if not (... and package.loaded[...] ~= nil) then
	require "verse.client";
	
	-- Config loading
	local chunk, err = loadfile("config.lua");
	if not chunk then
		print("File or syntax error:", err);
		return 1;
	end

	local config = {};
	setfenv(chunk, setmetatable(config, {__index = _G}));
	local ok, err = pcall(chunk);
	if not ok then
		print("Error while processing config:", err);
		return 1;
	end
	setmetatable(config, nil);

	if not config.jid then
		io.write("Enter the bot's JID: ");
		config.jid = io.read("*l");
	end
	
	if not config.password then
		io.write("Enter the password for "..config.jid..": ");
		config.password = io.read("*l");
	end
	
	-- Create the stream object and bot object
	local c = verse.new();
	local b = riddim.new(c, config);
	
	if config.debug then
		c:hook("incoming-raw", print);
		c:hook("outgoing-raw", print);
		verse.set_log_handler(print);
	else
		verse.set_log_handler(print, {"info","warn","error"});
	end
	
	for _, plugin in ipairs(config.plugins or {}) do
		b:add_plugin(plugin);
	end
	
	for _, plugin in ipairs(config.stream_plugins or {}) do
		c:add_plugin(plugin);
	end
	
	b:hook("started", function ()
		local presence = verse.presence()
		if b.caps then
			presence:add_child(b:caps())
		end
		b:send(presence);
	end);
	
	c:hook("ready", function () b:start(); end);

	if config.connect_host then
		c.connect_host = config.connect_host;
	end
	if config.connect_port then
		c.connect_port = config.connect_port;
	end
	
	c:connect_client(config.jid, config.password);
	
	verse.loop();
end

return _M;
