
local http = require("net.http");
local json = require"util.json";
local bare_jid = require "util.jid".bare;

local current_url = "http://xkcd.com/info.0.json";
local numbered_url = "http://xkcd.com/%d/info.0.json";
local formatted_url = "http://xkcd.com/%d/";

local strips = {};
local latest, last_update;

function riddim.plugins.xkcd2(bot)
	bot:hook("commands/xkcd", function(command)
		local url = current_url;
		local q = command.param;
		local strip;

		if q then
			local t, num = q:match("^([#\"]?)(%-?%d+)\"?$");
			if t ~= '"' then
				num = tonumber(num);
				if num and num < 0 then
					num = table.maxn(strips) + num;
				end
			end
			strip = strips[num or q:lower()];
			if strip == "" or strip == 404 then
				strip = nil
			end
			if not strip and num then
				url = numbered_url:format(num) or url;
			end
		elseif os.difftime(os.time(), last_update) <= 3 * 60 * 60 then
			strip = latest;
		end

		if q and not strip then
			local pat = q:lower():gsub("[-()%[]", "%%%0")
				:gsub("%%(%b[])",function(s) return (#s > 2 and "" or "%") .. s end);
			local results = {};

			for i, strip in ipairs(strips) do
				if strip:lower():match(pat) then
					results[#results+1] = i;
				end
			end

			if #results == 0 then
				return "Sorry, I couldn't find a match";
			elseif #results == 1 then
				strip = results[1];
			else
				-- We have more than one match
				local ret, title = "Multiple matches:";
				for i, num in ipairs(results) do
					title = strips[num];
					ret = string.format("%s %s (%d)%s", ret, title, num, ((i < #results) and ",") or "");
					if i > 5 then ret = ret .. " " .. (#results - 5) .. " more"; break; end
				end
				return ret;
			end
		end

		if strip then
			local t, n;
			if type(strip) == "number" then
				t, n = strips[strip], strip;
			else
				t, n = strip, strips[strip:lower()];
			end
			return ("%s, "..formatted_url.." "):format(t, n);
		end

		http.request(url, nil, function (data, code)
			if code == 200 then
				data = json.decode(data);
				if not data then return end
				local n, t = tonumber(data.num), data.safe_title;
				strips[n], strips[t:lower()] = t, n;
				if not q then
					latest = n;
					last_update = os.time();
				end
				command:reply(("%s, "..formatted_url.." "):format(t, n));
			elseif code == 404 then
				command:reply("Strip not found");
			end
		end);
		return true;

	end);

	local admin = bot.config.admin;
	bot:hook("commands/xkcdlist", function(command)

		local actor = bare_jid(command.sender.real_jid or command.sender.jid);
		if actor ~= admin then
			return "I shall not";
		end

		local get_next;
		local function handle_reply(data, code)
			if code == 200 then
				data = json.decode(data);
				if not data then return end
				local n, t = tonumber(data.num), data.safe_title;
				strips[n], strips[t:lower()] = t, n;
				if n > 1 then
					return get_next(n - 1);
				end
			end
		end
		function get_next(i)
			if strips[i] then return end
			local url = i and numbered_url:format(i) or current_url;
			http.request(url, nil, handle_reply);
		end
		get_next(tonumber(command.param));
		return true;
	end);

	local function do_load()
		local ok, loaded_strips = pcall(dofile,"xkcd-list.lua");
		if ok then
			strips = loaded_strips;
			return true;
		else
			return nil, loaded_strips;
		end
	end


	bot:hook("commands/xkcdsave", function(command)

		local actor = bare_jid(command.sender.real_jid or command.sender.jid);
		if actor ~= admin then
			return "I shall not";
		end

		local dump = "return "..require"util.serialization".serialize(strips);
		local f, err = io.open("xkcd-list.lua~", "w");
		if f then
			f:write(dump);
			f:close();
			os.rename("xkcd-list.lua~", "xkcd-list.lua");
			return "Saved list of strips";
		end
		return err;
	end);

	bot:hook("commands/xkcdload", function(command)

		local actor = bare_jid(command.sender.real_jid or command.sender.jid);
		if actor ~= admin then
			return "I shall not";
		end

		local ok, err = do_load()
		if not ok then return err end
		return "List of strips loaded"
	end);

	bot:hook("commands/xkcdreset", function(command)

		local actor = bare_jid(command.sender.real_jid or command.sender.jid);
		if actor ~= admin then
			return "I shall not";
		end

		strips = {};
		return "List of strips emptied";
	end);

	do_load();
end
