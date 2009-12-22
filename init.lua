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
	return setmetatable({ stream = stream, config = config or {} }, riddim_mt);
end

-- self.conn is ready for stanzas
function riddim_mt:start()
	self:add_plugin("groupchat");
	self:add_plugin("commands");
	self:add_plugin("ping");
	self:event("started");
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
					return bot:send_message(stanza.attr.from, reply);
				end
			end
			local ret;
			if stanza.name == "iq" and (stanza.attr.type == "get" or stanza.attr.type == "set") then
				local xmlns = stanza.tags[1] and stanza.tags[1].attr.xmlns;
				if xmlns then
					event.xmlns = xmlns;
					print(event.stanza)
					ret = self:event("iq/"..xmlns, event);
					if not ret then
						ret = self:event(stanza.name, event);
					end
				end
			else
				ret = self:event(stanza.name, event);
			end
			
			if ret and type(ret) == "table" and ret.name then
				self:send(ret);
			end
			return ret;
		end, 1);
end

function riddim_mt:send(s)
	return self.stream:send(tostring(s));
end

function riddim_mt:event(name, ...)
	return self.stream:event("bot/"..name, ...);
end
	
function riddim_mt:hook(name, ...)
	return self.stream:hook("bot/"..name, ...);
end

function riddim_mt:send_message(to, text, formatted_text)
	self:send(st.message({ to = to, type = "chat" }):tag("body"):text(text));
end

function riddim_mt:add_plugin(name)
	require("riddim.plugins."..name);
	return riddim.plugins[name](self);
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
	end
	
	for _, plugin in ipairs(config.plugins or {"ping"}) do
		b:add_plugin(plugin);
	end
	
	b:hook("started", function ()
		b:send(verse.presence());
		for k, v in pairs(config.autojoin or {}) do
			if type(k) == "number" then
				b:join_room(v);
			elseif type(k) == "string" then
				if type(v) == "string" then
					b:join_room(k, v);
				end
			end
		end
	end);
	
	c:hook("binding-success", function () b:start(); end)
	
	c:connect_client(config.jid, config.password);
	
	verse.loop();
end

return _M;
