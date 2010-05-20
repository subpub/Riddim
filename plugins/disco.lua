-- disco.lua

-- Responds to service discovery queries (XEP-0030), and calculates the entity
-- capabilities hash (XEP-0115).

-- Fill the bot.disco.info.identities, bot.disco.info.features, and
-- bot.disco.items tables with the relevant disco data. It comes pre-populated
-- to advertise support for disco#info, disco#items, and entity capabilities,
-- and to identify itself as Riddim.

-- If you want to advertise a node, add entries to the bot.disco.nodes table
-- with the relevant data. The bot.disco.nodes table should have the same
-- format as bot.disco (without the nodes element). The nodes are NOT
-- automatically added to the base disco items, so you will need to add them
-- yourself.

-- To property implement Entity Capabilities, you should make sure that you
-- send a "c" element within presence stanzas that are sent. The correct "c"
-- element can be obtained by calling bot.caps() (or bot:caps()).

-- Hubert Chathi <hubert@uhoreg.ca>

-- This file is hereby placed in the public domain. Feel free to modify and
-- redistribute it at will

local st = require "util.stanza"
local b64 = require("mime").b64
local sha1 = require("util.hashes").sha1

function riddim.plugins.disco(bot)
	bot.disco = {}
	bot.disco.info = {}
	bot.disco.info.identities = {
		{category = 'client', type='bot', name='Riddim'},
	}
	bot.disco.info.features = {
		{var = 'http://jabber.org/protocol/caps'},
		{var = 'http://jabber.org/protocol/disco#info'},
		{var = 'http://jabber.org/protocol/disco#items'},
	}
	bot.disco.items = {}
	bot.disco.nodes = {}

	bot.caps = {}
	bot.caps.node = 'http://code.matthewwild.co.uk/riddim/'

	local function cmp_identity(item1, item2)
		if item1.category < item2.category then
			return true;
		elseif item2.category < item1.category then
			return false;
		end
		if item1.type < item2.type then
			return true;
		elseif item2.type < item1.type then
			return false;
		end
		if (not item1['xml:lang'] and item2['xml:lang']) or
			 (item2['xml:lang'] and item1['xml:lang'] < item2['xml:lang']) then
			return true
		end
		return false
	end

	local function cmp_feature(item1, item2)
		return item1.var < item2.var
	end

	local function calculate_hash()
		table.sort(bot.disco.info.identities, cmp_identity)
		table.sort(bot.disco.info.features, cmp_feature)
		local S = ''
		for key,identity in pairs(bot.disco.info.identities) do
			S = S .. string.format(
				'%s/%s/%s/%s', identity.category, identity.type,
				identity['xml:lang'] or '', identity.name or ''
			) .. '<'
		end
		for key,feature in pairs(bot.disco.info.features) do
			S = S .. feature.var .. '<'
		end
		-- FIXME: make sure S is utf8-encoded
		return (b64(sha1(S)))
	end

	setmetatable(bot.caps, {
		__call = function (...) -- vararg: allow calling as function or member
			-- retrieve the c stanza to insert into the
			-- presence stanza
			local hash = calculate_hash()
			return st.stanza('c', {
				xmlns = 'http://jabber.org/protocol/caps',
				hash = 'sha-1',
				node = bot.caps.node,
				ver = hash
			})
		end
	})

	bot:hook("iq/http://jabber.org/protocol/disco#info", function (event)
		local stanza = event.stanza
		if stanza.attr.type == 'get' then
			local query = stanza:child_with_name('query')
			if not query then return; end
			-- figure out what identities/features to send
			local identities
			local features
			if query.attr.node then
				local hash = calculate_hash()
				local node = bot.disco.nodes[query.attr.node]
				if node and node.info then
					identities = node.info.identities or {}
					features = node.info.identities or {}
				elseif query.attr.node == bot.caps.node..'#'..hash then
					-- matches caps hash, so use the main info
					identities = bot.disco.info.identities
					features = bot.disco.info.features
				else
					-- unknown node: give an error
					local response = st.stanza('iq',{
						to = stanza.attr.from,
						from = stanza.attr.to,
						id = stanza.attr.id,
						type = 'error'
					})
					response:tag('query',{xmlns = 'http://jabber.org/protocol/disco#info'}):reset()
					response:tag('error',{type = 'cancel'}):tag(
						'item-not-found',{xmlns = 'urn:ietf:params:xml:ns:xmpp-stanzas'}
					)
					bot:send(response)
					return true
				end
			else
				identities = bot.disco.info.identities
				features = bot.disco.info.features
			end
			-- construct the response
			local result = st.stanza('query',{
				xmlns = 'http://jabber.org/protocol/disco#info',
				node = query.attr.node
			})
			for key,identity in pairs(identities) do
				result:tag('identity', identity):reset()
			end
			for key,feature in pairs(features) do
				result:tag('feature', feature):reset()
			end
			bot:send(st.stanza('iq',{
				to = stanza.attr.from,
				from = stanza.attr.to,
				id = stanza.attr.id,
				type = 'result'
			}):add_child(result))
			return true
		end
	end);

	bot:hook("iq/http://jabber.org/protocol/disco#items", function (event)
		local stanza = event.stanza
		if stanza.attr.type == 'get' then
			local query = stanza:child_with_name('query')
			if not query then return; end
			-- figure out what items to send
			local items
			if query.attr.node then
				local node = bot.disco.nodes[query.attr.node]
				if node then
					items = node.items or {}
				else
					-- unknown node: give an error
					local response = st.stanza('iq',{
						to = stanza.attr.from,
						from = stanza.attr.to,
						id = stanza.attr.id,
						type = 'error'
					})
					response:tag('query',{xmlns = 'http://jabber.org/protocol/disco#items'}):reset()
					response:tag('error',{type = 'cancel'}):tag(
						'item-not-found',{xmlns = 'urn:ietf:params:xml:ns:xmpp-stanzas'}
					)
					bot:send(response)
					return true
				end
			else
				items = bot.disco.items
			end
			-- construct the response
			local result = st.stanza('query',{
				xmlns = 'http://jabber.org/protocol/disco#items',
				node = query.attr.node
			})
			for key,item in pairs(items) do
				result:tag('item', item):reset()
			end
			bot:send(st.stanza('iq',{
				to = stanza.attr.from,
				from = stanza.attr.to,
				id = stanza.attr.id,
				type = 'result'
			}):add_child(result))
			return true
		end
	end);
end

-- end of disco.lua
