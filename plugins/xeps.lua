local parse_xeps, xeps_updated_at;
local xeps, xeps_short = {}, {};

function riddim.plugins.xeps(bot)
	require "net.httpclient_listener";
	local http = require("net.http");
	bot:hook("commands/xep", function(command)
		-- Cache XEP list for an hour
		if os.difftime(os.time(), xeps_updated_at) > (60 * 60) then -- Not refreshed within 1 hour
			http.request('http://xmpp.org/extensions/xeps.xml', nil, function (data, code)
				if code ~= 200 then
					if code > 0 then
						command:reply("Received HTTP "..code.." error trying to fetch the XEP list");
					else
						command:reply("Unable to fetch the XEP list from xmpp.org: "..data:gsub("%-", " "));
					end
					return;
				end
				xeps_updated_at = os.time();
				parse_xeps(data);
				command:reply(handle_xep_command(command));
			end);
		else
			return handle_xep_command(command);
		end
	end);
end

function handle_xep_command(command)
	local xepnum = command.param;
	if not xepnum then return "Please supply an XEP number or a search string :)"; end
	if xeps_short[xepnum:lower()] then
		xepnum = xeps_short[xepnum:lower()];
	elseif not tonumber(xepnum) then -- Search for an XEP
		if xepnum:match("^(%d+) ex%S* (%d+)$") then
			local num, example = xepnum:match("^(%d+) ex%S* (%d+)$");
			return "http://xmpp.org/extensions/xep-"..string.rep("0", 4-num:len())..num..".html#example-"..tostring(example);
		end
		local results = {};
		for x, xep in pairs(xeps) do
			name = " "..xep.name:lower().." ";
			if name:match(xepnum:lower():gsub("%-", "%%-")) then
				table.insert(results, x);
				--return commands.xep(msg, x);
			end
		end
		if #results == 0 then
			return "Sorry, I couldn't find a match";
		elseif #results == 1 then
			command.param = results[1];
			return handle_xep_command(command);
		else
			-- We have more than one match
			local ret = "Multiple matches:";
			for _, x in ipairs(results) do
				local xepnum = tostring(tonumber(x));
				xepnum = string.rep("0", 4-x:len())..x;
				local xep = xeps[tostring(x)];
				ret = string.format("%s XEP-%s: %s%s", ret, xep.number, xep.name, ((_ < #results) and ",") or "");
				if _ > 5 then ret = ret .. " " .. (#results - 5) .. " more"; break; end
			end
			return ret;
		end
	end
	-- Check that xepnum is a valid number
	xepnum = tostring(tonumber(xepnum));
	if not xepnum then return "What XEP? or enter a search string."; end
	-- Expand to full 4 char number
	xepnum = string.rep("0", 4-xepnum:len())..xepnum;
	xep = xeps[tostring(xepnum)];
	if not xep then return "Sorry, I don't think there is a XEP-"..xepnum; end
	return "XEP-"..xep.number..": "..xep.name.." is "..xep.type.." ("..xep.status..", "..xep.updated..") See: http://xmpp.org/extensions/xep-"..xep.number..".html";
end

function parse_xeps(t)
	if not t then return nil; end
	local currxep = {};
	for b in string.gmatch(t,"<xep>(.-)</xep>") do
		for k,v in string.gmatch(b,"<(%w+)>(.-)</%1>") do
			currxep[k] = v;
		end
		if xeps_short[currxep.shortname] == nil then
			xeps_short[currxep.shortname] = currxep.number;
		elseif xeps_short[currxep.shortname] then
			xeps_short[currxep.shortname] = false; -- kill dupes
		end
		xeps[currxep.number] = { };
		for k, v in pairs(currxep) do
			xeps[currxep.number][k] = v;
		end
	end
	xeps["0028"] = { number = "0028", name = "XSF Plans for World Domination", type="Top Secret", status = "Hidden", updated = "Work ongoing" };
	return true;
end
