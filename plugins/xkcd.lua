local parse_xkcd_list;
local xkcd_list_updated_at = 0;
local xkcd_list = { };
local handle_xkcd_command;

function riddim.plugins.xkcd(bot)
	require "net.httpclient_listener";
	local http = require("net.http");
	bot:hook("commands/xkcd", function(command)
		if os.difftime(os.time(), xkcd_list_updated_at) > (3 * 60 * 60) then -- Not refreshed within 3 hours
			http.request('http://xkcd.com/archive/', { headers = { ["If-Modified-Since"] = os.date("!%a, %d %b %Y %H:%M:%S %Z", xkcd_list_updated_at) } }, function (data, code)
				if code == 200 then
					xkcd_list_updated_at = os.time();
					print("debug", "got "..(#data or 0).." bytes of data");
					parse_xkcd_list(data);
				elseif code == 304 then
					xkcd_list_updated_at = os.time();
				else
					if code > 0 then
						command:reply("Received HTTP "..code.." error trying to fetch the XKCD archive");
					else
						command:reply("Unable to fetch the XKCD archive from xkcd.com: "..data:gsub("%-", " "));
					end
					return;
				end
				command:reply(handle_xkcd_command(command));
			end);
		else
			return handle_xkcd_command(command);
		end
	end);
end

function handle_xkcd_command(command)
	local xkcdnum = command.param;
	if not xkcdnum then
		xkcdnum = #xkcd_list;
	elseif not tonumber(xkcdnum) then -- Search for an xkcd
		local xkcdname = xkcdnum:lower();
		if xkcd_list[xkcdname] then
			xkcdnum = xkcd_list[xkcdname];
			local xkcd = xkcd_list[xkcdnum];
			return xkcd..", http://xkcd.org/"..xkcdnum.."/";
		end

		local xkcdpat = xkcdname:gsub("[-()%[]", "%%%0")
			:gsub("%%(%b[])",function(s) return (#s > 2 and "" or "%") .. s end);
		local results = {};

		for i, xkcd in pairs(xkcd_list) do
			if type(i) == "number" and xkcd:lower():match(xkcdpat) then
				results[#results+1] = i;
			end
		end

		if #results == 0 then
			return "Sorry, I couldn't find a match";
		elseif #results == 1 then
			xkcdnum = results[1];
		else
			-- We have more than one match
			local ret = "Multiple matches:";
			for i, xkcdnum in ipairs(results) do
				local xkcd = xkcd_list[xkcdnum];
				ret = string.format("%s %s (%d)%s", ret, xkcd, xkcdnum, ((i < #results) and ",") or "");
				if i > 5 then ret = ret .. " " .. (#results - 5) .. " more"; break; end
			end
			return ret;
		end
	end
	-- Check that xkcdnum is a valid number
	xkcdnum = tonumber(xkcdnum);
	local xkcd = xkcd_list[xkcdnum];
	if not xkcd then return "Sorry, I don't think there is a XKCD #"..xkcdnum; end
	return xkcd..", http://xkcd.org/"..xkcdnum.."/";
end

function parse_xkcd_list(t)
	if not t then return nil; end
	for number, name in string.gmatch(t,"<a [^>]*href=\"/(%d+)/\"[^>]*>([^<]+)") do
		number = tonumber(number);
		if number then
			xkcd_list[name:lower()] = number;
			xkcd_list[number] = name;
		end
	end
	return true;
end
