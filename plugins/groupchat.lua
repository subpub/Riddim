local events = require "events";
local st = require "util.stanza";

local room_mt = {};
room_mt.__index = room_mt;

local xmlns_delay = "urn:xmpp:delay";
local xmlns_muc = "http://jabber.org/protocol/muc";

function riddim.plugins.groupchat(bot)
	bot.rooms = {};

	bot:hook("started", function ()
		for k, v in pairs(bot.config.autojoin or {}) do
			if type(k) == "number" then
				bot:join_room(v);
			elseif type(k) == "string" then
				if type(v) == "string" then
					bot:join_room(k, v);
				end
			end
		end
	end);
	
	bot.stream:hook("stanza", function (stanza)
		local room_jid = jid.bare(stanza.attr.from);
		local room = bot.rooms[room_jid]
		if room then
			local nick = select(3, jid.split(stanza.attr.from));
			local body = stanza:get_child("body");
			local delay = stanza:get_child("delay", xmlns_delay);
			local event = {
				room_jid = room_jid;
				room = room;
				sender = room.occupants[nick];
				nick = nick;
				body = (body and body:get_text()) or nil;
				stanza = stanza;
				delay = (delay and delay.attr.stamp);
			};
			if stanza.name == "message" then
				local replied;
				local r = st.reply(stanza);
				if stanza.attr.type == "groupchat" then
					r.attr.type = stanza.attr.type;
					r.attr.to = jid.bare(stanza.attr.to);
				end
				function event:reply(reply)
					if not reply then reply = "Nothing to say to you"; end
					if replied then return false; end
					replied = true;
					if r.attr.type == "groupchat" then
						reply = event.sender.nick..": "..reply;
					end
					room:send(r:tag("body"):text(reply));
				end
			end
			local ret;
			if stanza.name ~= "message" or nick ~= room.nick then
				ret = room:event(stanza.name, event);
			end
			return ret or (stanza.name == "message") or nil;
		end
	end, 500);
	
	function bot:join_room(jid, nick)
		nick = nick or bot.config.nick or ("bot"..math.random(10000,99999));
		local room = setmetatable({
			bot = bot, jid = jid, nick = nick,
			occupants = {},
			events = events.new()
		}, room_mt);
		self.rooms[jid] = room;
		local occupants = room.occupants;
		room:hook("presence", function (presence)
			local nick = presence.nick or nick;
			if not occupants[nick] and presence.stanza.attr.type ~= "unavailable" then
				occupants[nick] = {
					nick = nick;
					jid = presence.stanza.attr.from;
					presence = presence.stanza;
				};
				if nick == room.nick then
					room.bot:event("groupchat/joined", room);
				else
					room:event("occupant-joined", occupants[nick]);
				end
			elseif occupants[nick] and presence.stanza.attr.type == "unavailable" then
				occupants[nick].presence = presence.stanza;
				room:event("occupant-left", occupants[nick]);
				occupants[nick] = nil;
			end
		end);
		self:send(st.presence({to = jid.."/"..nick})
			:tag("x",{xmlns = xmlns_muc}):tag("history",{maxstanzas = 0}));
		self:event("groupchat/joining", room);
		return room;
	end
end

function room_mt:send(stanza)
	if stanza.name == "message" and not stanza.attr.type then
		stanza.attr.type = "groupchat";
	end
	if stanza.attr.type == "groupchat" then
		stanza.attr.to = self.jid;
	end
	self.bot:send(stanza);
end

function room_mt:send_message(text)
	self:send(st.message():tag("body"):text(text));
end

function room_mt:leave(message)
	self.bot:event("groupchat/leaving", room);
	self:send(st.presence({type="unavailable"}));
	self.bot:event("groupchat/left", room);
end

function room_mt:event(name, arg)
	self.bot.stream:debug("Firing room event: %s", name);
	return self.events.fire_event(name, arg);
end

function room_mt:hook(name, callback, priority)
	return self.events.add_handler(name, callback, priority);
end
