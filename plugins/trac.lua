--local bugs = {};
local s_match = string.match;
local t_insert = table.insert;
local to_json = require "json".encode;

function riddim.plugins.trac(bot)
	local trac = bot.config.trac;
	if not trac then return end

	require "net.httpclient_listener";
	local http = require("net.http");

	bot:hook("commands/ticket", function(command)
		if not command.param then return end
		local bug_id = s_match(command.param, "%d+");
		if not bug_id then return end
		local format = s_match(command.param, "%w+$");
		local url = trac .. '/ticket/' .. bug_id;
		http.request(url .. '?format=csv', nil, function (data, code)
			if code ~= 200 then return end
			if data:sub(1,3) ~= "id," then return end
			local ticket = map_table(parse_csv(data));
			command:reply(
			format == "raw" and to_json(ticket) or 
			ticket[format] or
			(   ticket.component .. " / "
			..  ticket.summary   .. ": "
			.. (ticket.status == "closed"
			and ticket.resolution
			or  ticket.status == "assigned" and ""
			or  ticket.status)   .. " "
			..  ticket.priority  .. " "
			..  ticket.type      ..
			(   ticket.status == "assigned"
			and " assigned till "..  ticket.owner or "")
			..  " - <" ..  url .. ">"
			));
		end);
	end);
end

function parse_csv(s)
	s = s        -- ending comma
	local t, l = {{}}, 1        -- table to collect fields
	local fieldstart = 1
	repeat
		-- next field is quoted? (start with `"'?)
		if string.find(s, '^"', fieldstart) then
			local a, c
			local i  = fieldstart
			repeat
				-- find closing quote
				a, i, c = string.find(s, '"("?)', i+1)
			until c ~= '"'    -- quote not followed by quote?
			if not i then error('unmatched "') end
			local f = string.sub(s, fieldstart+1, i-1)
			if not t[l] then t[l] = {} end
			table.insert(t[l], (string.gsub(f, '""', '"')))
			fieldstart = string.find(s, ',', i) + 1
		else                -- unquoted; find next comma
			local nexti = math.min(string.find(s, ',', fieldstart) or #s,	string.find(s, "\r\n", fieldstart) or #s)
			if not t[l] then t[l] = {} end
			table.insert(t[l], string.sub(s, fieldstart, nexti-1))
			if string.sub(s, nexti, nexti +1) == "\r\n" then l = l + 1; nexti = nexti +1 end
			fieldstart = nexti + 1
		end
	until fieldstart > string.len(s)
	return t
end

function map_table(t)
	local ret = {};
	if not t[1] then return nil end
	if not t[2] then return nil end

	for i,v in ipairs(t[1]) do
		ret[t[1][i]] = t[2][i] or "";
	end
	return ret
end

